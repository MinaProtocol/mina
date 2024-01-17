--
-- PostgreSQL database dump
--

-- Dumped from database version 12.17 (Ubuntu 12.17-0ubuntu0.20.04.1)
-- Dumped by pg_dump version 12.17 (Ubuntu 12.17-0ubuntu0.20.04.1)

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
-- Name: user_command_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.user_command_status AS ENUM (
    'applied',
    'failed'
);


ALTER TYPE public.user_command_status OWNER TO postgres;

--
-- Name: user_command_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.user_command_type AS ENUM (
    'payment',
    'delegation',
    'create_token',
    'create_account',
    'mint_tokens'
);


ALTER TYPE public.user_command_type OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: balances; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.balances (
    id integer NOT NULL,
    public_key_id integer NOT NULL,
    balance bigint NOT NULL,
    block_id integer NOT NULL,
    block_height integer NOT NULL,
    block_sequence_no integer NOT NULL,
    block_secondary_sequence_no integer NOT NULL,
    nonce bigint
);


ALTER TABLE public.balances OWNER TO postgres;

--
-- Name: balances_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.balances_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.balances_id_seq OWNER TO postgres;

--
-- Name: balances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.balances_id_seq OWNED BY public.balances.id;


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
    snarked_ledger_hash_id integer NOT NULL,
    staking_epoch_data_id integer NOT NULL,
    next_epoch_data_id integer NOT NULL,
    ledger_hash text NOT NULL,
    height bigint NOT NULL,
    global_slot bigint NOT NULL,
    global_slot_since_genesis bigint NOT NULL,
    "timestamp" bigint NOT NULL,
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
    receiver_account_creation_fee_paid bigint,
    receiver_balance integer NOT NULL
);


ALTER TABLE public.blocks_internal_commands OWNER TO postgres;

--
-- Name: blocks_user_commands; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.blocks_user_commands (
    block_id integer NOT NULL,
    user_command_id integer NOT NULL,
    sequence_no integer NOT NULL,
    status public.user_command_status NOT NULL,
    failure_reason text,
    fee_payer_account_creation_fee_paid bigint,
    receiver_account_creation_fee_paid bigint,
    created_token bigint,
    fee_payer_balance integer NOT NULL,
    source_balance integer,
    receiver_balance integer
);


ALTER TABLE public.blocks_user_commands OWNER TO postgres;

--
-- Name: epoch_data; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.epoch_data (
    id integer NOT NULL,
    seed text NOT NULL,
    ledger_hash_id integer NOT NULL
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
    type public.internal_command_type NOT NULL,
    receiver_id integer NOT NULL,
    fee bigint NOT NULL,
    token bigint NOT NULL,
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
    public_key_id integer NOT NULL,
    token bigint NOT NULL,
    initial_balance bigint NOT NULL,
    initial_minimum_balance bigint NOT NULL,
    cliff_time bigint NOT NULL,
    cliff_amount bigint NOT NULL,
    vesting_period bigint NOT NULL,
    vesting_increment bigint NOT NULL
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
-- Name: user_commands; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_commands (
    id integer NOT NULL,
    type public.user_command_type NOT NULL,
    fee_payer_id integer NOT NULL,
    source_id integer NOT NULL,
    receiver_id integer NOT NULL,
    fee_token bigint NOT NULL,
    token bigint NOT NULL,
    nonce bigint NOT NULL,
    amount bigint,
    fee bigint NOT NULL,
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
-- Name: balances id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.balances ALTER COLUMN id SET DEFAULT nextval('public.balances_id_seq'::regclass);


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
-- Name: user_commands id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_commands ALTER COLUMN id SET DEFAULT nextval('public.user_commands_id_seq'::regclass);


--
-- Data for Name: balances; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.balances (id, public_key_id, balance, block_id, block_height, block_sequence_no, block_secondary_sequence_no, nonce) FROM stdin;
\.


--
-- Data for Name: blocks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks (id, state_hash, parent_id, parent_hash, creator_id, block_winner_id, snarked_ledger_hash_id, staking_epoch_data_id, next_epoch_data_id, ledger_hash, height, global_slot, global_slot_since_genesis, "timestamp", chain_status) FROM stdin;
1	3NKeMoncuHab5ScarV5ViyF16cJPT4taWNSaTLS64Dp67wuXigPZ	\N	3NLoKn22eMnyQ7rxh5pxB6vBA3XhSAhhrf7akdqS6HbAKD14Dh1d	1	1	1	1	2	jx7buQVWFLsXTtzRgSxbYcT8EYLS8KCZbLrfDcJxMtyy4thw2Ee	1	0	0	1615939200000	canonical
\.


--
-- Data for Name: blocks_internal_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_internal_commands (block_id, internal_command_id, sequence_no, secondary_sequence_no, receiver_account_creation_fee_paid, receiver_balance) FROM stdin;
\.


--
-- Data for Name: blocks_user_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_user_commands (block_id, user_command_id, sequence_no, status, failure_reason, fee_payer_account_creation_fee_paid, receiver_account_creation_fee_paid, created_token, fee_payer_balance, source_balance, receiver_balance) FROM stdin;
\.


--
-- Data for Name: epoch_data; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.epoch_data (id, seed, ledger_hash_id) FROM stdin;
1	2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA	1
2	2vaRh7FQ5wSzmpFReF9gcRKjv48CcJvHs25aqb3SSZiPgHQBy5Dt	1
\.


--
-- Data for Name: internal_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.internal_commands (id, type, receiver_id, fee, token, hash) FROM stdin;
\.


--
-- Data for Name: public_keys; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.public_keys (id, value) FROM stdin;
1	B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg
2	B62qmqMrgPshhHKLJ7DqWn1KeizEgga5MuGmWb2bXajUnyivfeMW6JE
3	B62qmVHmj3mNhouDf1hyQFCSt3ATuttrxozMunxYMLctMvnk5y7nas1
4	B62qjX1zTYtJqCg6c7VHYjTzGTEgzzYxE1ArGZMZQpoukrGXaDFq5aW
5	B62qqDJCQsfDoHJvJCh1hgTpiVbmgBg8SbNKLMXsjuVsX5pxCELDyFk
6	B62qkbdgRRJJfqcyVd23s9tgCkNYuGMCmZHKijnJGqYgs9N3UdjcRtR
7	B62qqMo7X8i2NnMxrtKf3PAWfbEADk4V1ojWhGeH6Gvye9hrMjBiZjM
8	B62qnbhwgpyQzSSo9Sea1wEbEMjr4WhtzeQWRzAfA94fjros6UbSiF6
9	B62qpPsUkaaWC2VPzY9MBnQtUxYRFCCKHf9uXTZri4duUXGb3F3tmX6
10	B62qqwnvUmQNkVWwmz7Q4DEK7frPYMU9wCawjrUmA39Af3FtaVz1WzY
11	B62qqomhidaLc7wbYPeaHkGkzXVNA9z7pqf8nL7UjiSZKmLmVT1mPEB
12	B62qkYyCBSWdRQPkC1C3KdhNxvoVDxK3sUjVBMkV3GZ13daCPszYxJ3
13	B62qnHA8SYctwuFL11w1ZQ6MPyxCE7a44mqG1wk3DQzwkE9uzCGk5iZ
14	B62qqnZWjM68fMq7jVR19fGDnrigtYX9WZ14enXFiLZkE13WDe4aLy3
15	B62qoZ1MjrwCCGgq6AUSxb9dx23FzoS6rABLtmCxKh3TuNaymR9Lsnj
16	B62qrMBmbcHLZbsQsmdt8TjJAxLzAohmMRmoBweq1sXw9oBfQRd8ayV
17	B62qpFzTCTjEyTi1xRsyuE8aJD4oZvbWVmC8H6jpguHZuyoXKHZpd43
18	B62qife4P6rHK2iTnqYDGdnbnLBDHCWRcUBLPt4hiKYCxntRbSggo7k
19	B62qmC9ypxkPz9pgwxvrUPL65b6yNQTUWpUgAkqN5R7UurwuSaUV2r3
20	B62qmoWgbRAE4X5GyD4kMs3CH2wj39tjMATZLWb7zjg4kWn3Pp1QuiP
21	B62qrMi68WSSWpmb3Yfp7ztzAFx6gUyF26VAzPNgYEoYKRASRj2pqZK
22	B62qjWCpSvwkVNub2Cmbwg7s15RMK3WpS4zCyGTjacCcLeWx4JHdCf1
23	B62qpR8BVdV86jgnzCzHebvAcSVnKb4yWigJBrUWmdDUZy1qsHtHUrG
24	B62qnx5hKBFHZFUFjpEXzh2du8wRegCHrp3kL17gY7qxMBFQcBycJM5
25	B62qoGasCeX5M5HyK95AKLh6eXK92tBgAfkVJPuS8A8NkATuMjRxSbF
26	B62qj1zaXZxuRGzYfuq2KBSWvoei73uGZw4yqzRNTW6xiff5TGy6VJe
27	B62qrzgDHmFmnuq6HSLBd7kERXepvfKcoBqTRS4JcBCMETcdFk4rwG9
28	B62qr5Ckko96JXfECA79Vp1TNn6KUYLQ8x6m1QVk38e1uNgupVK1j1v
29	B62qrJBx8f9rpna3QzJwpuFX3Jzb1DmdVJxyXof6nDBLBrYryR8Kh4s
30	B62qkrhfb1e3fV2HCsFxvnjKp1Yu4UyVpytucWDW16Ri3rzG9Ew2cF4
31	B62qnzyWXFmSALrg5E5mSrYo8o1WaYEcFZ2bDDMxNUUyP4y2SCsQtB8
32	B62qpnYDuvSsk8tKgDxnXEWySd5zuyj7tbTc2qzPQ9eU9mjJnZEYkeu
33	B62qnxw3GS7TPFiHydSwH8qd2FJ6tm9j2qk3xUFi73DvP6H6LWteRAh
34	B62qjZD48ymWaV9jra4LyZMhLUiJa4XbXpH5JxD1pFsrg1pjXfbcjRf
35	B62qq8Zswd4JHeoTkWAVs5fSYDwywKcZDnNiZpyHSDJz3HqD7A73Esc
36	B62qraStik5h6MHyJdB39Qd2gY2pPHaKsZFLWVNEv2h3F85T4DmtjC7
37	B62qqfnfVegeAMKRsUaQX4zUrPttA2ZZgZy5fX8uw3cfRMh4HQMbmvJ
38	B62qqrn3yzWRDJrUni6cRva4t51AcnY1o1pM4xpB78MfHUH3ajZu1Ko
39	B62qkUQyaxfFNtoMXoZwa6Ar9pXPzhzeWCEsvvN1Eb6KfDeP5PgXJFv
40	B62qndRjyGhBTS1GJEmSX1VQr4u7zcDXATpgqddoLF9SSScjcMqqoB8
41	B62qogNhfVvpDE2mXJMjJ9CT6DtVAMr6Be71xFS7b7sdNYSfvaQBAkb
42	B62qoB8RRURcit5keJXvq7uXzYkgN4Lsz5GFaVpGYdA9vAiASy3iBcD
43	B62qixi4dP7DcKdTNcK8jobtv9qKFjxf7ZgZVoQcJXVXkeAULe3hT5E
44	B62qn7HrKKt5ia1dvGYHuvuFGLdwNSXUSAERQgvS2yZbZvVaK5biQef
45	B62qijDC2gCTtcqYGnUAc9YgH2Uw4fzr8xEKKL4faZmWyAypgEe3oWC
46	B62qmdsqUB7b3GYTWmCTGSioxMKeSesj4JrcRQRmmPRqwTtTo6xdYDz
47	B62qqiV28EmAXco2BuXoL4wSz3UHCv7zG387FnqYoiCkwNJWRywJ3KQ
48	B62qnSEkCtGJcTD4eJJvSHnZNsqP8aww4kdW3GGfYir4XTnXTjeED34
49	B62qpujwq2HQtwJnjj9vYgjDq8hJyXnTdMWSMyZxHBQQqEoEYfybL8x
50	B62qowpMhZ2Ww7b8xQxcK7rrpfsL5Nt5Yz5uxaizUBKqpeZUqBETa31
51	B62qo3mKb7LGbJhT5f1SqeHThWhYeQkQ7RH59S5imK69pa9WeTMudi5
52	B62qixNMEVEmPMMgt4M4FDdDHdUyj5ZaZtpN5cTzPiWFYubHaUUs7CD
53	B62qmG9DytrgGor58qQaxhSwdCzR5skbZtVWs3GsY5ywXdAoDCqBaNf
54	B62qmAkbNGBdaWSM32cqvKWA2nzySujjJbKPxqNfs2V6es8rXZDtsjv
55	B62qrdiTDeX3AP6aHn62WUsQ3dT7mH7zA6YUGmJ5R9FJDTac4j6DmPA
56	B62qqoBaTeqq6K5kpPEBh22HHq2BJ3ukegb4csDDoyoaFzdpgKLidYS
57	B62qqrTPrFvi3bvcGrM7zCgc7YWug74PhzRBGzBr19ao5teNQNigxSZ
58	B62qj5tVzR8JEoLWYYE95tXaACqGD7ew7vk6TnTCVdEfCo6nUtvggbV
59	B62qoXQhp63oNsLSN9Dy7wcF3PzLmdBnnin2rTnNWLbpgF7diABciU6
60	B62qiW2BLxkiXcjVrhuhvxH8QTMcFHQ5HKs7yfuqwx2pooyZKsjq6Ei
61	B62qoJVEF8K9n5Vsqm3dtuqSzxAFC5ppL5zcdYL8gJJFUuedQoLTLbK
62	B62qpYxXxVozLf4QRhxfKptR5Pz2nJoCoPVwiDjvJGAiijf8aHDoy5f
63	B62qo7F5ccXnDoeH5tazsr32uy6cfM3qjjR6AofCMBb9axfA3EzSgP5
64	B62qrJb5c4yaeL5fDCrEU5tGsmJWbcfnkdW1pMQbGT1rAnnA2JjAP6h
65	B62qjwAoLA1iT82EQQidZDDovQND5PeJtmcZXq7USbNDGEqgYnBbKam
66	B62qmbNN5xihYm7Z6b5sEdJNzAqppJ3jnk15QppaJUCuqMuWfMP3JNX
67	B62qjZfVCSKPAeFp1GZBZFPp6jP2fdAxLQiGr4NrhCk5trGPRMHFthD
68	B62qoUaRmzxG3atakF3bnpHT8enYCCq9UaUyAV4JZXyN16GMgJmYkHC
69	B62qjYqfAWQPikmwLARjwG9vpaNgCYEFT4RaEYjoNEsmXCVXb3HWonL
70	B62qqj1YzdmiHE43B3CYXbi6vU7o4x5ZiwVWnR2WQiUxfx1CNDHnzg4
71	B62qnj6wXxdvbPkas4Fxrz4cbncpE2yMPiMfZT8kmDSvGScYpT3AsFF
72	B62qkvWArUfzfzQYorVPSqKUbv45BHE7FWYgSgaCAFRVipVQjbZE7Ss
73	B62qnEoBEjGFRb735UzzoGAzpQgvUK3umJu4aZZsakkr1E64MVC7ySK
74	B62qmLP83WABda9CceWg5RjbzS6rNiwFg8FzxmZyXKyj5duSGhE8qAo
75	B62qkDvSJpbRh7GYq7jwuKaRCbQ8ifw3syWyVexJRu6KtZNbTpNTR5t
76	B62qqpJCDYAFpFMgm1FSCwvY1E4r4EPmoH7bBJkuGsGJ3hm3cpFLGSE
77	B62qpmq5XCNpv12G125tnrGtcJJnMD5qEQ8Riw9LLEtjxAQ1wNjywYm
78	B62qnXPppCEaxMQYSqYPNq1nYWFSYLJvmCsQmuD79F4L21sBmUoT34N
79	B62qrR8VjjKrijdZ9HgUg5D33CrNCWhDdJr8gvmdFFCizCGgaeANhXT
80	B62qndKQurk75DGcgVb1ZLv9NGfCtAAP9g7JtoB9rAuaT93WkE55rbz
81	B62qkd4tZQGe9mo5tK3wQi5PUoMdtUGtLWps6Se9o1qWdwNwuUtdWdr
82	B62qkBgrQRS47DadYBiGRpo4y9h4wCiYmRzwgCbHbidN6ScsuFViVuh
83	B62qrAJ7wiP6sJwjM3RsZX3Xzp21BpfkF3yXA49TxPNBHAKrjPLbx4J
84	B62qnmxotgbGMHt7NkJBNFBoZC6wtHhBvoV472SfHzR4RmJsRZAtc1S
85	B62qj5TbymjFWUsjHnCDNfzbFbacKzXwnHdgDJDoAZwcs5GD2sacGMc
86	B62qmD4V61qQ6FFGEB4dJ7Nn3VVSxzdpJXRnevBJBMhTTphP2DrounC
87	B62qjM1iHPTCF3MDqhX5xiNhUHYzuxDKsk5ioKGE6AwvhAWSeYF9p6W
88	B62qmYVkkqtgLRvizHiqpQdBqQgiKv2kyaeQKJ2JmzbNN3J7bvACKpC
89	B62qqS5kLArkb787BAJD57Q69VB4MAJp18rrxdZBojPnd2yw1ULsYbX
90	B62qrYkGp44a78p3t6uifiBq2wwctJw3k8u88sKLLAgdAZFK1G8UGcH
91	B62qpoiUSB7FaqZQ2tHTveQ5rCS1phjByQZkTVeZzzRZXcRC8cvB468
92	B62qoWeaz5bDeo7Zt7ckkXnWEYTdNRUGQGgMNofUJ3hZcAG1KKbo4Ky
93	B62qpuQzCRgYUH7Ehi8gsLdRWVc75uKHwTUmsbsqTUMeMF7DcgpEJbb
94	B62qmdgx2WFkeWd1eMchRQUrhW426RFMZ6ZZzgv5itAiQfsjYcpC8FX
95	B62qrYveCMCW2tr5J8gu9T1rh817zsq7j8cjc9mHEecQS2tRMnoNTsy
96	B62qpYmDbDJAyADVkJzydoz7QeZy1ZTiWeH1LSuyMxXezvu5mAQi53U
97	B62qphjuHHaPY37THFRMYRQsVCf1JgEE6k512cV3S4RmkmdutMhzZmr
98	B62qkNThcughFM7r3aaZZFoZEyJRJiQY5tpFCRQZNRrb4AWEb4kFVmk
99	B62qrPt73ni9xPW55gBova4hDKyhXBuBo9yWBT2N94CC1XAfFmXxLsc
100	B62qmgDU4ygtzV5ZueVWgSFjYtkatqjSTmj4z2jbjN5XjfLMrmK9zkx
101	B62qrUCF3rqUMTXxjEWpmLprwJ1y9fyN2UgJB9DLQK36iHfcv4Voequ
102	B62qkqN9V4TQZWBCzPW7QiYh87CTUJBtVxUHze2cWxAUviZtwkWvZg6
103	B62qo23z1xZBR34du7GUtN6yGvSV9sXXWp2VHUNaCQVuasSwx5mnnXU
104	B62qrzTgzDJ6n1UojoypnHx4P1onR61r3RZkFaqFcgQ1mVUPY6cJzSr
105	B62qoK7sfMMxbx63h8Pmn9fCCSDBaW3WNyhniC2pbbB75kYZc1Xsk43
106	B62qrN1MZnXy15VXkh3D5XiNPQVKQLr4UXqBPFv3E4NHNFrzANC4wFb
107	B62qjW8gnXUWZH4zeMmHGgj73BRPt7bYkWQPcw3VG28QvfDJC2gvQvn
108	B62qqoY9tz6C4QafDyUGsxvJTJonnvJ7iCLyzzMLcDAoCAAE6nzEyGb
109	B62qoSqKkE5B4HPxWtidWGDty12o95nicTb81fW6HbUDPycQvDBs1cD
110	B62qkaDe8abFe8HpTgnc85LBxbg5pnoBvFraxePy67YBXmymWeW2BcE
111	B62qpCVgRNPxcoC5eQKDXJoHRRfcNSRjzq2YHymp6AFciH1bsRXkkf9
112	B62qn61vkYgxbTcxgbv4U969wrn97BZCZQrH1tUXFCevt2gXZENX9jM
113	B62qj49ZC1dvWzGNMd5VVxSVQhZv4rzoKd7TdsVSUAsHZ7x4mHXAWjH
114	B62qouDi7P2eXT2fRYji3a9rGCVQ6BpWt2iwb8y2yZnHL6VdhXtDcCm
115	B62qiWir45GBE9PWWoySrVnB8ERdL7QiykkfwjyzytuDSQTbibigSuw
116	B62qqDDZYhfU7mNcQKJfWHDJ3JjVTi6dG32oWiWY3KrrX4mSMLdEuUj
117	B62qnbxW6CVKmmRnwhYXc2EprVZXFBQVJj31W5FFLpSJgELsAkuU6jJ
118	B62qk2k9kWwdJ1C6H7QmxgK9JWkXNRZkssTvaUnNStLuwuo2NyopLoD
119	B62qoimVsUrBatqSRFuzGCWUHHSA6F3pA4hjX2Eb6QKDdrqV6oJFru2
120	B62qiVpQaFZer4iZY5n6TpmquHJtkvNhJWmR41XiWGZbmhQqGvQdUjE
121	B62qrkCaGXGWJC7JWzdg1nJv7Y1opgWDTDi6XknSYwTdrkMpTrg9AXc
122	B62qj28AitWwLTU3HAhtoW34nJ6LkyHU7XKm5wC84q1RtF4ho1yEgGn
123	B62qqb9QnByFcRQ2BGY6LjogXvsbknCxUPbBzhbrB1rpFoKR9Ys5VpE
124	B62qqLH53Wv45FVdA4tP41kqsCaSgJwe367qzfPp7Kxj9fGaQdrE3sE
125	B62qmy9tB4Nf9vVgg4ZJsiS8psBvxoSKZrWPmXRFX9tSQMyWRq39Kyw
126	B62qoSHqhByDDSMj85436DyUDRm1HDayaC95Gh5GinNANJD9EceHQkK
127	B62qoqGCXRr2yJRyRpRGhLZEP8a8B6rpBiMqxdwf2YxwYwpB3RoTGpM
128	B62qmLHunUCqVvXShJD6Qtg353wtM5fvDnJJu3F1AkeiwEMmbrnhVjg
129	B62qr5X78ew3GvKfbUUV3QqYiSK6vgUNCuLSdfMWCQw5pjp4L5TZw9v
130	B62qrLc7FgHVZ8dXyUzKHsL87E7Q2dRZRgjJcD48Lrnyx5FcyH4jLtd
131	B62qrNuUMrV2yBaGCWKqxYJNEihwjYxAZi9w3z2yESK8XxZs58aSB5y
132	B62qipAVcEkYgwwJfGsZ3TBhNKG8QU4J5JuFduWDzAUrUnUTR2C1a8L
133	B62qooos8xGyqtJGpT7eaoyGrABCf4vcAnzCtxPLNrf26M7FwAxHg1i
134	B62qoa7TmS3zdF2fqTsuDzEybrr86HwofCs4aYxeioeyRhQXaJQqK9J
135	B62qj9PPXDZuviJRDYPY66b7Jz58Qn13feGm758GpbQwJLp1S7oi825
136	B62qrYRkV2BKxoH6Nwuz6hMdZUk8U5Pefo7jdRWD8STdi6UL2MMaTaj
137	B62qkqCoR4oFfaEURsoG3z8EYuy8jVRoC6Lz5WGRNx8siQydG5y7Syn
138	B62qmFxVhebAGSspFQMdctwQRynupZH4dgZb3bxedcEumyaA8X9PzJP
139	B62qmAgjG13dd7gH5HZVaFRXZMFsLUVhs6qyqJdzQbhFs8SU9rycSX5
140	B62qjAijvK54GbYNLvZtva5tcDk2BbZAvtF7aBU7cm6bpxxpLAopJqt
141	B62qqqYnBdaqtR9LKfmXiQEdtdaZrFbh2P7YLi12u2JsmL8XHuBY5CA
142	B62qkag9ybmAzG9areQNg5oFNrsKjMc71q6nVnRDRDVo2XBxBcuzrA3
143	B62qmEgp5XSe6jsrJjuTkNS9fpvcUSZDBzs7uqJ8vEg5vgJ9BSVYDXm
144	B62qoX5oLk4m1wDmtJak7FHuEjxbGhpeARaVzkrn5gCHwPS21b1QEXz
145	B62qpRFS35fkGa3a7LEWhN8kZEQecobt1SZueunGXcxffcqFLKzgXHi
146	B62qkpma8whukuHBYjqJy4qNq2KoADVoyxccrkHDcw7332ifwGSVL56
147	B62qkes2AXQFszcXKtS9ZHVofoPRZJXiXzSfYVpH48vs14LVQXPoBfY
148	B62qosavysGuVW49xaiyvA1EaUPEA5zXdQWBrJp2XUtW9x5i49zL7yX
149	B62qkyzCG3cZhEVNvtec6Yt3MHxZkXhrKJeDLrKUVNPEpFZoa2gM5gA
150	B62qpLST3UC1rpVT6SHfB7wqW2iQgiopFAGfrcovPgLjgfpDUN2LLeg
151	B62qjV8B1C3nbRqKXEiREjNQCLuCL4Y75PPpwcFqWBAvFWN3X2iJJJD
152	B62qpxWMmCV9Qgx8EFQ3a6cpofDoX8DVMWrb25SCcRrsMqb19kuC5Ue
153	B62qoVopcNoQPFydweGWUBnJJbrokkebVDiWGmAzYoaLysrFfzNCbya
154	B62qnizET2q8NkKB3JfNYugpzq6Yddpufb5YvwWNgoxpTHUxMpVyrcc
155	B62qj8oSkVyBfVim9JWehGAa8eN43Q9RU5HQdzPSiy4XmS5uVAG7dJy
156	B62qr5UCVcHxSvGikJadNpn2bX7rvXRKzXQppPf2boq3eutzwxnTnkh
157	B62qriyGf54B65U6gZFFYzSzc5goHg381HRkYmgXnRqg9QMt1kZo7ac
158	B62qpk6VZxMqJjpYK89DFpj7SA3aE7kVyNAEw3G4TTxsK7NwEkqeMyB
159	B62qkKecntugWPMLfArv8cQqQsTGU9NG7gUakJzAR1cFTfG19QTfzbD
160	B62qpyhbvLobnd4Mb52vP7LPFAasb2S6Qphq8h5VV8Sq1m7VNK1VZcW
161	B62qktcFUDAniQGBamMXRabimiT3igb8bpbxok5h2yf3cSyw6PDH1BG
162	B62qjqVBKhE7Y3Kb6U1PqFt6vjk1uAFWwzeyDB2WD8MMunyHmBu2s64
163	B62qqvN7pFGTSzQgmwgxVV3nCAjQSE1mTpwHfQabpM3kZvKhYbhTRbC
164	B62qixTkfYwADQSS9SHL9NRBoNKvmfCYxQAPhoLiZDA5RsrzqiRPLHp
165	B62qkN1mBrN8GvxUSLxRHCvpLba6QX9TXgCLh4TcgxD1Bstewfnx8ff
166	B62qmbwRekMF7vGprxsSXT6XEPYVQcYN4dMdRZeZmAkPWwq1g4zV33Q
167	B62qrsEeZGxCaCKpMiHoTxWtT5Z1wrRptdh32xV1nr4GJHz5XDus5bj
168	B62qp6RfHVKvyLaA4Nf3NTQ96cxUTz8yxpTuZWAAvzdt1vbxqzxRGjF
169	B62qjTanvKuhcGC3vY9H4SaMsn6m5e1PGf7td7UAXZbRzVsmiB9oM8E
170	B62qieCpKu6W91BrH9vyjbHGrs8PpuRFkHSh7vorLJnCp4akJecCY6V
171	B62qrXo8soPBcTi8G2EHAUxJk1hpsQKqBoc2oXsHkwczxheJTeMzrCh
172	B62qjok2BD2jB6TArVM1oGDSo16xk1SYGzTwZSjx63WbtZy4BuzPBDj
173	B62qiwhAyp8prsTLatm4EUp6XvDEVAWyhY3YEs5RwTsi4wDVd21SfoU
174	B62qrEpQMYwujaWHNswuY3Gud5i4FLkrRwds5RNYPVyh5FwZJXgsfPV
175	B62qkdWpePqJ8XWogMvzt8kHWG8LGzG9gsYEuK5gbWePbFAZYohAEzd
176	B62qrop8ZLmVpu8AD3a7Hsqi9Yp1D29RJ7tfqWF4rVpAt7bUEZCsWpx
177	B62qjp6bK1jLdWVUXvnrhKmfuAuvLSMtCyysKEKVxewrL315BSPeMP7
178	B62qpFW3CEiqiVi4bRpDKf7ZNq3qNUKbHKhxQ68EUQ8QeeK5pksZVsE
179	B62qjb7gJQvsbEnSTLTft54LbT6YVWTAFL9zizzb8wAeSFudP5j75eW
180	B62qrV2oyYf84jZbQHdqH2TyUndafsL134WMpf5yDafmQ6ZGMxUiTmF
181	B62qqL6UUFFPkM7m3j2mmuEfjQvQdsKSGTu2CqYeYftb4sr5ji9DiHu
182	B62qnr5wwBn5dTuYTRgKobVujZYWLNBYA9marvg3y1e3yfukRmwqZv2
183	B62qpjEJn5boKL7nqM7G49V4zY3jeE2M3czqG8FXJEbAADstvfF9T7Q
184	B62qoiEyq2QHR8m3sw9eLdJxZzA5ttZ8C4EYfRs8uyE4Gc7Bi5rY1iA
185	B62qjyBDHWZfC2WX4sT7n6oLyexjzd7AW3o8r8yrbXFyjJnzwFDrGHc
186	B62qmyp8L897rHk5qwb9XVbwDge9e6q6ENYAH3sPkyvwA3cDXrxvV3r
187	B62qnAkxbs4gqZVnqzpQ6vbuoAD4VQSzYLydjt1d7eV9na7kXky6vV3
188	B62qpkiJW9ZCXtFm9WeY43ajhgwxVn6QWaeQiy75Jhpbv1hiaF5zswU
189	B62qmxHeEYE5fYVUVeLKHV2MfLcRpJMhtpsUaTeXmuGaw6UjTUwpQ5i
190	B62qkZhutQR8e2ijgAyChi7Ba8MEhRnnYfEVG2Tp9qsAff8HFgWgDHD
191	B62qmnmynER4sq7nV7i5YxhbcLaWQcqnZJhriVVaJgsmGzJt7mQq4uG
192	B62qpH4BktZFp5in5jKcfFrUqAYKbpU2RhH8iHmLKdraVWxjdbUMbpG
193	B62qiV4rtGrXstynn9DFMaTmQ9BB9C3kxLHmjsG57dyAKHxoqooMZGS
194	B62qowSjKkwtESnVZtaZpvuPJFbkygn5CZo5Ym9AKTHX7hMjMEhGGKY
195	B62qrJr7qJF5VJRrChgJj9QsskoGdJzVNJoMk6dEtnEBNKci4faYWfe
196	B62qqz5V5wjzg24v7HUCyJUD9a2Xk5gJrb75qyLwE4L6Rbo9XtTZyGB
197	B62qifMfsFYqLJ6Cf1KbwPCxsNwFA4qqcMeqWVvAZi37W6oRDnHRyYz
198	B62qpwsWhvau9zqmWvzXoHzWbpk6dXEx1UXP3nLQWmnFAuZAoMCKEYb
199	B62qrnHPpAF26JphstpLvPPC1L9sZZD4g8R1SNhCQuY36fbuXS9jaEK
200	B62qqYPMx7tRYqSMHzXrEb1HSTrLmsTpdDU4GnqTcP3egMwVH4pdi62
201	B62qjHrPXCydF2R9Vc2Gp9Cmn55eodSKUmhW7fQ83zwkXkMR77MHk3e
202	B62qmmjvVdhd2VBRyh5PJHiQkYkqLDgqa9uq5nfC2dM2MdfWt4ennHW
203	B62qnf4ieWyJWjLhL4GGXE3tLTLofHfgLTK6ZCPrrRnFrS4KEZ94m5K
204	B62qqWqjKKD4BBJVbPG9T56rStDcveAjBxoAWYGTfY75wyV3yQ4rYRH
205	B62qnyBEcf6gcaazmQWCPQCjizwBeBi76398k2VQCQ7mH6QzeLHMyqt
206	B62qp7Poht74axa1BJMWmN6MzAwEAnr2uRhi444YDvE4KAm57LEBKET
207	B62qpymA2yno7Qawq6vaK4aXtnNttAcvG4Nt23tFvbMPyG5yhEKMUSu
208	B62qjwh3KGD68vYySr2V1jcpkZ9uZZSoJJHzNWCgQQiLU3DAoab5NT5
209	B62qmRZKEwHnmEDh9Ywxf3be1AGrkFQnPES4FMKhDR7APWwQ1ouBwof
210	B62qrqi2dnGJeaLjULNxSFRqATdFqWetY3f3d7cHwyi6qdk9Y2MJPyS
211	B62qptxgjmuegvWsWgtjsWGyADwm3xx4sSydnV3iVNJHqtoYnWfr429
212	B62qq1xGN57tke8jJ3EuJMgFmgWQRoip6kKoBsTuLxsGXVqQXMN5oVj
213	B62qkf8bdX6AhgD7jR3Cs1YdWFkQpAaLAjWxqGijXG2memeU9o8i7Z8
214	B62qqVJQeDg8fxvedBP24KMFWcFB9m21V4tuLcJH9UQNdTrXxKrGrvD
215	B62qq9XP15kBmNexCELYxduoLr3HZKqRDQhD3mBx94rYPjjCZU1y9fm
216	B62qmCh5jJAJKgDaNL62rYcQuERxAm1q2bXKAFuCvKNH1ogZme4KES9
217	B62qrPLQL66L4BKeCFeypQHcAmKCcjtEr765o78xUJE335puxC9NViD
218	B62qjBp3TgwngdrKkK69NjrhTFS9KSTriLFiv2FKvnhGfjbYFFZCT9M
219	B62qpXuwSUQhfYfiu3CrZLXGzrCrxzkMNQAUZTu1bmxn8rsGH9zv7aQ
220	B62qj8Ld7mfYLuVramqiG9UWVjeLp5gsNy3pRCc5eF1heDMzkciNpF3
221	B62qjj9qsR77nCaqbQ5Q1XE2321gCYophTf1DfYi1uzQsCQvTFNsExg
222	B62qjwkotonAhcHsdGh7TsshXjdLXZQdJkTY69E5rtG8vCEVePraF82
223	B62qrQTNYpC8xQK2r1APUksrApXnU37YyZFhFtpWip3x17zXnGuPXcS
224	B62qrB51a5BAUn2TDX2y5RdMFmu7ytb1phVdKM1PjMjBPDjdzrHPp9T
225	B62qrrMKTKBGUCPstWDWBHAey3VRkztZFZPr8FfoX7qxdPTpwinMedN
226	B62qo5HvEcc98R9N1Y19hpsvkyvHbgFc2f4Dg3EnDAaFo1N3MG3xWJx
227	B62qrCmbqncUWGMDo7uEFzf4JSE6kSSuEuMMQwxAWxp8wYbVE8rdX5P
228	B62qjVX9MmfxajW5kBPjQgkTcs32MJHtydXfVdtCs1qk28bEcT6ekix
229	B62qjd92F7SH34QN89c2a27G7H9UM7EdFxWMtnmCVKh7jSW9WBq1fLV
230	B62qjzaoqL6ShpuMrpseveR2wpsBe6WfeEpc74evonStZebJg3Qu6jG
231	B62qkEHwUWrwMiToMX7fnRVtaET75RiFHvkFhd9up9bJhneipecEBx1
232	B62qnQsZYqubnj2tQ74m664TQ7CRmARquvq3p9pzaS2dikjxPnpePt2
233	B62qq9WWQBH8Zy6uHEfQakYGRcCAruHRdaQU597WFR5qf5T99Cab3rE
234	B62qoTCCaXTdQwiN3C1JYZkgjP4L8rKQrrrqpnGWhsSHjvSPzYVqTWR
235	B62qiksZ9WSGYb1pg3AvgzoQwqQy62F4pao1X2BNfj8hJFjovnh28Cw
236	B62qoSTXoK57i8UQ8RecMv592EkTjNQcSWpyVvJ6Ck6xgpBzvUFc6CG
237	B62qmNM9wRYRw5MdFfjwHCC8egn6aYayeuhVy4fpqFpahb1Zo1Rz3xn
238	B62qjDdeNBAc1AemCQ8fGYcLTCuqZGimzGUb4pXdzYws3wCmYFCDTQe
239	B62qp5dgv9tGSdD2DJDgJC8m5K3ah3mazxVagMm6pM5pJzX5QuPp8H6
240	B62qnLbQjbgBwQgPuLg9A5syh1Q3hwT8ecsFZ5dvwdtWRbsLfjjUH4D
241	B62qpwAqAJ5HaJT3iJgoFM5vC9gSJ1u2b9tvpRXx3Ns8mVoZTUDgGSL
242	B62qoPXEf78Lc2DG7GA7oU24Cd2986VxsCosABomT46JRMhYAmVfj5M
243	B62qpJwpBqDKDHFvv9uRDXHX2Tczc93zpNhYFcZAVXWm2KrSX7831Hg
244	B62qj7tJG5rxdy1hxo2tPo8xJGN3qDHwQdPqq7UMH6xGfhyfUikyKV8
245	B62qkoKSs9aAJLYPUxeqnRS28DRzTPfLkSonNjViXxM4bWQhVhYi82F
246	B62qprj7x2ByZHbVAf8r7k4fZKR4f745ysQA3fYgZh3gSdPoWXCDry7
247	B62qowREyBtVMpp8RVkbmfvZgxryNUzcJnRnH9LRs5xgAXkHhLyBEyz
248	B62qov9yv8TayLteD6SDXvxyYtmn3KkUoozAbs47fVo9JZSpcynbzTz
249	B62qmr9wnqsmhgThnSHvNKM6JtpWdJM2iQ4GPtUJk6ZjySeNiEyJmvk
250	B62qovgqKTuLjiCuzkPgVS56ex3ygxvGn3m9Wvwa9w1ZUo2EpuGdS5i
251	B62qk1oVDgqaoURSd4GY2KmENSYu8fnx8b7fuZSyVfruQF8gsd28D36
252	B62qmVkhfGqvfYrybuY3pgGjbLifcC1Wy1hLC7VtKHmvypuhancbueR
253	B62qjNN4wmuSdk6sS47Kpfi7CzdSEsf8Qm3HtmNCyxFhE8zxufycgQ6
254	B62qikyGBRHnK3Gsho2LzLTDXUXjVrQBm3StqasyWKsTNHexaxYzpG4
255	B62qmeYkyQGyqcdyjagRt3M4rpyZoJLoBK7Abv1ia4LBDumJfDEF2nV
256	B62qmMGz5dWhmrx7JgKtnmb4mqu87tqXsMr6wcRmnGzHrd3Y43iwhG9
257	B62qpgov22FLzdo7XoG2T7fz2CyxYqQtCBJ46SBscA6Vsv54qVD1oGy
258	B62qkd1a21WXpBc3kUrD86yty2VH3w24vC451CwSPbB3M6vStSBDBZi
259	B62qkMHhGvhdnDHYrwmCZC26VeZWwv18kn69pZzvXCxhi2ZiMJ8fEF3
260	B62qrQD8tyWsVArhMe42biJifujSr3hNpw3tRVtUakuUtRiBLmczChc
261	B62qiVNpFfuhEQyYUeQR82fxe1Bp3RXvc53JG2vedVTNSMR9Q5srxdh
262	B62qndynjUPACSp1Y9T6RppW6CU3K34wYXarR435Shbm2FD9un5AZjg
263	B62qrD4yGS7R7SutQnL4QqG28uwnRvX6hxAbyyAKiNn2HTkAv9x1BYq
264	B62qpnRWfM1SYB3z4tXbobpjQC2Gk8Kr33xQmk1vRpeMsfkcK4ButNb
265	B62qkTvL5o8LqNb6AtVR84smE4qgTJh2uySj8ufQd8cG8Qy4rPP1UDg
266	B62qmERM882YuYsXyGqnC9uLUZ3fS2U94QxcL43n3AdApti4pDA2R2Y
267	B62qm4AZDUA99AekfUfk1jufXR5KnaY7XFNUhd5tdV256voGdvwPFGR
268	B62qnd8XmGgeSWZ35bdbpKeoadr5vz3JV4rgZ9dZqu81o3K1npGUHuu
269	B62qqZxbrmjDz3ERbroPuHrgYZVEbWxoJxhMxmb6U9xcngrN98p5KyW
270	B62qiWVHJ3AxuSqK4hzkYQavBpnHBydNFSrNwyLWXizSnE4vzL2XTmn
271	B62qpNeSeFNHadM5LXXRZbQRUgpKXUWoVond8aoLpEVTnPG9zun2Gm5
272	B62qmcoErjsDd1XNsxpjPC7GUDYug7ersa9f2Si4jdD9Yom9N8z6578
273	B62qivKQokyen8VSDaaDaCKWx5BkBKDgei4yk8c1GTeP3b6C9DgmuFN
274	B62qr129iT5tEPohSHys28XrytPysFGFNXLFn1ETjGuZzTGm9wdHRey
275	B62qkeoF3PFQn7g9U7XNuyCvU8xqNxCA2qDgAkiefRiyNTZ7dzvjLvz
276	B62qmvmCN8qzDBKAD6M89hvGQeundPcDHhq5DrU57orGGKyT8NtrrRe
277	B62qpybcoHEEVNZUUciKrfMMtVV1uWq6HSjbK1jSo66LkMojeTDHzhD
278	B62qr2CgfiqKX2pVNkKTBKnHK8SAwqhHW1KUcszTp5Maivq1inYhRea
279	B62qns26Zzs7njXiz17AbJ9pvz3YSWa6dvXXN9vtNcJ4BTo2ZHSWQwN
280	B62qpiyGNhmLJ6JmBUqTaNJgHwkRkjQJ3PzarAmHfn5JmELY4RNPHot
281	B62qk2EsEpHX55gnZc8iASSekm8QYjh11NjZf4FjZNp2egdLi7bL7np
282	B62qkkWqU99Tk3n7voHNREo9KAtioaaYa4s55tdvEWHDYZj1wxYEvaD
283	B62qjFSKy73vyxJALB8DZLjXky1hqjpSUAMpumm5ZV4mMhT5gs9Mgcw
284	B62qou778MhEYT3qzuUL6LhsmSVMpB7FQn9ZkWPsYcHNV6LgCLDHcoP
285	B62qijd97DPQUp72zs3AiLo4dkUonpZtEZpK18oMK7G6xyX9YQdNJyJ
286	B62qq8itrQ9vYFGoC9orJWspS5TQ1BT2xtQCp5tmradoHYX3G277FYm
287	B62qkXTjDCwsYrDx9k65KEfXEn62ohVWNK895Jm26VQxt8nBhXcgr9B
288	B62qp8mnjoN15msN1LqHYXFUtqRGWjMhoZUysC8Bm49dMmNhhrPQmJr
289	B62qizN5gwSDjQXX1Ef3EXYEwQitNggDx8hdz9mqVCD8PDYvg7q7qKY
290	B62qrr4HsyQDc8BHf875XHizovkMqfXYKFxqxdcLPNahHnz1GZqCmXL
291	B62qpQeu4Td4CiTFU2C8bQXFgCefBc8rvvnG9C6Wfb2cz9YcQWaxomB
292	B62qqyn8atzjXyihkgRc9kMkKU6hnXtthqyM49Yz6FncyHqxkoLNkPu
293	B62qkEp3uw8fafP9koMTpxKLj5dEBvGRi5zWCE4hnvY5RBqHoJJwg26
294	B62qq1agJKStqQZedzMkEN2Bv7sTMHZprd7QJV8b8QAD1VuStCwyj8u
295	B62qrX53T6oax316MjjywtpTERrbRpDMxanZ66YEFVQeyvi5LH6LL9n
296	B62qopUvFqDi7UHtMtJyVsBPGGUKSmsaVr5C7qadxFQB5PJNxVan9R2
297	B62qpwieQeKnhXA8MEhsWAZnqA6qR2X82m6WfLqgAG82M9wnVCCsDNM
298	B62qqnCYD9sL3VjxeDW6z241xBr73bvEyX5TjGnrX9cad445Ut3vaZV
299	B62qns9cPvDwckhJXHpWZZ8b8T8oUgoF4Enpax5zNVBYYMtQwHf4Cmp
300	B62qkDvMb6vPupuP6qXKH4Lqw8fLJui5NcP61sJo9a9GKpQfteUPPt9
301	B62qryDkRZFK5r6DtWFiNhQhXDMWK5158MvoRhH8HSZuBLP2HLSqWZG
302	B62qjJPwZ81Z39Sg2WJ5tNPcCFBqwSeYZd68w8579eggnSyhFgGscuY
303	B62qoZ2J2WZKrNDUvLqKszzHSTYa1G49HE33JYf1Ux3U54LaLLNThhX
304	B62qnoQLkdjimCnRMsFZMA1GSgLA8HZGzBKxLsVWjRoHdtipcqmH9Bw
305	B62qiWSe63weqBN3vpnUyagnMkYmvRwKKQJ4dKckuJFsojUAYY56mfx
306	B62qp3NP4uGMRwBLBcr1JP8yzF27Wsm4QhL6yijJqo3Po1gZXWHiZxo
307	B62qs1fcaLBgAudDzGoTW9DYDw5U3BZ8MwbGAQ2gPazPrxtAemrKCPR
308	B62qksHfcCxo5gstt7aUnChtRTvuaHKW6EXJbEnYrJ6rikiYfLq1qrg
309	B62qpHpeTCVYbnuhZexBqz5tCSAWKT1izgCFHs8n9EqvrLzppLGKXqJ
310	B62qid7mcNh29WVifR2qWQDLJ9dRu94EUcbsgrTr9fdFMGsPQzWv8Qo
311	B62qixmqCUR4GPHbbG27BpjNstYfYmfB1QwEzWVCaYs9TpSugweiVvX
312	B62qowm5zNjGsDzC67eTc4zvjXwdkPRUKHFzeSDRjm6FBojzqmNfNhH
313	B62qjKEsfg8hiRVUEcUjW1RstNtyhMes6hb5wfcgSZizfXU26SLk4cT
314	B62qj2AqXEq6hdzaiFQ7wNSQ9TrzHQKS5WRnodXvdM7w1pRDc4GsgMV
315	B62qoXS5hZEidS6xdqAFMhY9tttfkevmsoZAaKbpJCq427CVGreGGcz
316	B62qitncPRoGgcufdUJdbJ1CooTz7fQuttqxBM48toKiq9ZqHPJyLpW
317	B62qoPwGzCmaAtHYXSKPSFyDU9R2RS9LiAEKJB66KwBUXkepBfMmWPS
318	B62qq3WS7BeAMu8PtfJjrPYNNz9cJpa6EJTfTkn7pQS1pPddapn2yDV
319	B62qrqeuQmW7F9RV8Uuzj98zj5LkYATmSenTvPP6ZmdsXK4scMYW2oL
320	B62qizMCrBRUG9keWLbDFCJBJbDY1tRkeqagsD2bLPCno1zxhPVYFNq
321	B62qoo5DaMn4iZeVijjm2XnoiNhQTMCdWixHtNMGaD9kcGd1z988toe
322	B62qn88ZcEijJNNRAimr6AQVa4jJPuY48dLzuLg7UMcKfmaTQFkeXXk
323	B62qpza4Xqp9GTDcsdjGJabz5M682oy7AudCD1jkqsMWHuzynLMfcKz
324	B62qjU8FUq5CmJ6MWFFEM1KGVb9DfZSvSmDCD1U5vgxrpDxAV3JZDrj
325	B62qksK8pRH8WtH5iNzv9KPVnY3E7KnDHFBLZmC6MgP9DBBJBxtKMYR
326	B62qkfCnyJpqtHmE53DCWQ15KHJXd36GazCaPrCznrmrsXoUjeSyurJ
327	B62qqgLQoPgy9YzsVKwB1KBuyB62TiQJYawDubnhf5gewKJo9qrKdnG
328	B62qj9MASPt6AcfxHawZcwkjFEfQqRVTn6HghdBmtEKvudWuRnhyEvG
329	B62qkNQ8SenMi1kYoHMHwbK7q3i26yLSpPM84wxiqsDvxFBHwna8Vtn
330	B62qr61ij8ZPW5BX6GMs4UNW1Ry29Cjbn2Z2LVyLkGJH3JgXJwx2jiC
331	B62qrCsLRjBPcr7pN8wRaSsw18PvZrzc3W2JAFrpt7K3YuJtAfMe62U
332	B62qj2gPKXJW6S2Q5qZQ2FZiL5jcMMvHdZYx9EWJnNDeRkTKPURSSPG
333	B62qnmuq8SMKR3JFBvkdDEuAGQnCQAC1cH59KJCmqG5NksGmTfxBE2n
334	B62qq3JeAaCrwa4XRtmjxmpXox1XZSgcSUXLPcKtcb4HnN6p5MzzYzj
335	B62qkuJvHscWoTsvtAYfzvGgsbw7YRXZpkFXr4r6QL4fspkZvjjh8Y2
336	B62qnSEt8wbrzWPr6iipnmTuwkNBMGB3e4ayg7hDkGXNLEzq3BMnCnk
337	B62qkkjmwsCMeX42PjL9DNPssKAupBojQT6Wd2ZZYeBq1EF7PTwKV6x
338	B62qid146JcZD6eSrDt2p9iqrQC6eTxRxYB5HUyg5XpTezsqP73WWRR
339	B62qrcpCwQNeFJvUru1fdVBWCfTWae6n7WcAacgxKE7W5gKAXyTV8yv
340	B62qnkCQqXyeXvbMavAG9U9cZ8JJi5XB7fwKMJoSEemzhqCWHQxpe5j
341	B62qmJ9xkQTANN7g1MENQtWFb5GHisESewUGLP17P6gPc1aentpPknd
342	B62qpBAw7SPHqDJyWDxfXCwQzJJ9ddDVxXNPckF4Vz2GKjPEZaXZpHp
343	B62qodJCdovJawjWjeYyttgjqJXfE9cn4UqZHqPtj74N4zrDZB4X7Gi
344	B62qjz89NS8EiPH5dM4HrBEDdKUxn2h3xAurQDXV2rKZoJiizkRt5eb
345	B62qo5tnoVeYMWW7EwNHCeUVvBU6ffxog6zJa9CZemj3XBL3adbrQTp
346	B62qko73kcCQVCk3sZbxjCNeyB7Npxf4NfNdENUdfu93YLAUJ48JYTL
347	B62qm7PZqTRPCJCzxfEhERiT15SobMmcEFUYEXuUMn8w6esvYwbLfvJ
348	B62qo3wqcK4DVFWxGe5tT1eswqQzsE5kbT1PGUXjcenBQ1rNbFZ7GZK
349	B62qn1WvJwssC85DFfCn3ex3r91oHZbaUSZt8npGBZ2XpVdM1LRwpHB
350	B62qjqtLRExnb2fyMiBpv6nC1ckGuBrCY9mXtTTcf5x7GD3CG6sU3Ad
351	B62qrkPTrY79TGSUV3E69gMTpfPjztPzTC6TZxwEy9P5d4nU5EVgxQs
352	B62qjCrpAF3n197SVLwY8UsugdxekMJhjJ5rKPYNsZ8XTAs4CBeJnjX
353	B62qjmwNZgQq5s757XqHqtQxiXWQECqan9bUFAQaRVFYP8tnFKQKRjY
354	B62qodH3aWczywdoKsgixMBcMEmsg3ruSfFjXNYR11du727MdyCDuW1
355	B62qngpchppH4j7gtkHWnZfAzRm2ak2p2mBjNHtWssoEvhK2Ev4u167
356	B62qpJa414g251R6eWAEw1FhEzfR8YjQMrhbVtBQ1kMRz4C7hVeRAN2
357	B62qqu7KbdrtYdGr5f66RvNRG983iKvVXgUUfsRc18ZCPLVw9naVLe4
358	B62qpZ4Pav4t9e6ir4UAuJdi4JEPwvvNfkWMjm39rkXZMDgAidTpS8p
359	B62qmax52Wd2AdXKEatbX1cFYecQYsgpXwzzejAiJUw79x4wAGucDyY
360	B62qpNLG53NfZ1HUJUtNxTCJonDJmj9Q89wFWorsuNszQarxRqdcfMS
361	B62qkpDyPDoGMWFdnvH9QADDnw5ixb8LUu57CDMXQNsDaUdq88Pu47A
362	B62qknJSP3q28HrstZ8trCWQR3DGaSWzYuNQSi1JkZxgbyuxGdp3Fw5
363	B62qkr7ThcgibRwBiv6u556iBi134e2CTnSvQC2xNMLFNTqJWL3Dmob
364	B62qrawWiZbmyrJaB94CVpi8Fmd3Lxw5m3tbXo97hKJkZPkn4dHe6G8
365	B62qp2gg2aP1dxg7FPXVemWcgP5zaPBJoeeZAC3EgHtR4sTibD3Eaoy
366	B62qjgMVvo1JTaG6u1pBFNzvPGivGTUeq6TtbauypeVybojD5JdWjvW
367	B62qqS4q8Lk8uCWBK6xsJcHpXSqpabvgNWm3gHaXAEaFGANU5Eqs3KP
368	B62qoYEmT49GcVuhEpLiU8KBVE2fPENG7qdNRZkDjjBfYoD6XMDwAUa
369	B62qq5F7VB8sSDPDs1PHhmbmL37dtR427EWPmthtt7YpPPdy4fXN8e9
370	B62qm6LvKxET3xCAW5JdNWAekCjyJJFxJdYYNcpGNwvhe15yyddYife
371	B62qjCZxxdKpeTSXzxCUfcVmvDnMeUkebm3XgLLK3AewfawZkCkziZL
372	B62qmKeoHvaJL2MtoQaSUogTyZyFMKDeno3Rhc7VpxRE5kCa4EwJwH2
373	B62qqmgjAjoKRgt1ptEdqnFN8LTmBKj8YdSEVKxnAxcFtiRXYeUV3pD
374	B62qqAmP51fjPJ1FFVXP8i48f4zhEyhRr47v2X4iVfSVtMiMG489HAH
375	B62qqmRRU7WmBLegW368k92xdtgavt2NRKKFeneQN41udU3RJK4RypJ
376	B62qpBhnHWtr4sq1sRcy4Nd1WHA4o47fV3tu21e41vCZ87LGcCQCdW8
377	B62qnYgvJNeUwF48YyYMh2WDpnV2n69sr2KW7jDJQqRtPU4vtchiB4M
378	B62qpoqqu8Rhc6E5GN1McsT6VxL5i3DGuQkt3k23JVKZrNWxqGM4mDn
379	B62qnFz5DTg4Keh5x6P9pnctAzvgiHZyarCdEx7GYRew1H2Kw6G66Ly
380	B62qkUcq8Tt1h5PMXWoc9n4Jk6zsbG1YZoTeB8jQzS9JLrtL2HP6dyt
381	B62qqVDmmLafLcJG6bkXCZfmEMcnupNLoud3sVsxCn96AzjmJKXwqS8
382	B62qqdcf6K9HyBSaxqH5JVFJkc1SUEe1VzDc5kYZFQZXWSQyGHoino1
383	B62qkBMexQj12N8fYEeXMz23qVYpPtXwJYsnmRGsXJYcprgie5onhdz
384	B62qreVP6TddxX5CySuko7gqxVwzRmQyYzraHp85dzYG9g9ixPbVL3D
385	B62qm65cfsaBjb8GkDAmRgBLS6bnypkdUL2TYhEL7eAts4aR7UhtAwy
386	B62qidnhLeB2P7AiF8GtETeM9PEfCvWMajFxDaYWsxkXiajT1T4CUMP
387	B62qmBArXh34ZoJEXutPgSw8N5z3YgDm3vX2Vwfo5k1x4uZvqbQ8TYS
388	B62qoewSfNiLeUQUsmXQMmCGcD1pkXX7FWq2bD3EgsBojq2UaGG2Gzv
389	B62qrhxaun9CinfJobHb3uGp4vEXd3j2kg6iNhsWZnhDYzUyEMW2cdF
390	B62qqy7DHHzo4ryzUYdycH9jNaPYGj1vMUPZxQ2VwSq134EjHKeYiGt
391	B62qpRa7iZ64Ws7aH971V32TRmDAcLBfuxppxx6s4CAvmC3NZfBjxeq
392	B62qowXgtSfrWgMwvP6yxe3Z3JnpRHKZhsWCRLETNvMnT7ezeT6rA4c
393	B62qp8TJyLYVFR6FnQAZ4A3aBKCMkEZzWBo3VSuGkyhBMdFAgjhTtE9
394	B62qogfTBYu9xSbweoUywdPWxEy3wZGhmrv5fGydAyFTXTPnGY6vQPG
395	B62qpcGGx2UxNMgxqM9DrJuzkoB8Q6KrGifTVT6hdq4pwMUAsEtduQJ
396	B62qqa9zE4zcqLx2emeoeCp59f9iKBMiLtcQRDpBsqrxGvhrVciwB7G
397	B62qrUdqiAzLuzFRsBcYEBzvcCtSFkydyNcpyHj5Wu2umSDAztFnbRX
398	B62qikygSmv245hJZQzAhAqxfqeNiyPDZUS9MME4HkP9oFNhij85XUp
399	B62qjdxqhiaRQHExFvnEDGH2prnAU8xtnw5urmWUNsK4oc8AyJSDwNU
400	B62qmXi6YMzGmKhw7CK1M8VAybRyErq7VytkXULkjTjiB1FjTdoYxX1
401	B62qr5Kat2je68ni2TyEZiaPCf5iKPxCZPWjsEgdEJh9g3ZCB7GLWXs
402	B62qqE4CAyjRqdYXa4Q28dA1hHmtKBggmk6ufEWe71tXbM8DWpUwVMi
403	B62qjYZCaRMB7cXWvCowkhEHiHmyhwu7AnDvQhHeDUfuaZ3c6y4JLgF
404	B62qkPMHeYkG7q7uPefcU18CpKPpisST4YUay8dg8sZAKMrxMQpADPB
405	B62qrqVYXRsroeuX7oTLSXEsXg6DziGL1LmJJ4TER4X9rSQHsYBobMn
406	B62qmBNz8jAeKVm3Avkdqs9V796r7cXSLQ37RMi4ECswgqERwn5P7Uo
407	B62qmhWsLASA4x715y2FizsvzjggcsdDkTcqxHu1WkPuoHD2EnFHZiR
408	B62qo7NFdpzFbTyiUj5Uhks5TB9fapKc6jNDNFnFYtqCyyBNiFMhsET
409	B62qrUAu3VZ2JUA2Z8kbFVWcd5vGehomxCnM2LptvpKbuu3y5GNxbb7
410	B62qpwLQcUpYcn7RqDkDHGxAoWwy5AZ9uSab9s5YtwBXcAow81nLhEk
411	B62qnZG3J8PBwNrx4hLsgDmt7JHzFwTSJ7H8peJwRhKcHtsVsa2Ye7k
412	B62qrLFnh5BWLjHmsnrX9ABW9QVRDe237VKXQ3EobeXDqsLyY2iQD9g
413	B62qpc6JFovnLFZAa8JEAs9QQMxh12H2Xj4NFFjpyE2NZpoCQXRQxwZ
414	B62qojCVaJ3dKYgBUieccF3A3qzVEotn4Qd5k4tNU8QPNgVhZTpLwit
415	B62qpUXHbTVzyvZT8cs6fS3h8g74PNa4nFHTC7rhK29geJECWZnj1EY
416	B62qpW3ndQTvtcCkRj5jyPTbDFzM1wu5TiPNcSiya9htTzrZwuhExJL
417	B62qnucUMHz7Dw2ReNgWhmR5XCvPeQjJWPReuQ8GwPyY4qj1otGBiKr
418	B62qnRkPAoX5ruTEcRYPXZgynj7z6eVRcpozaLm4ixXhYpEbZc4jW5S
419	B62qnJ6gLytERFTXgY2tsW8cP3xDPhpJxuQFeFRMq6vz1JbrDz968Qt
420	B62qjRDJA1NUddVunp1iRerMg7Un74E3xPUwFX7NhLx1spgct4REDGh
421	B62qoa7ihzF5PiP66kFYctKKqmBy3JyVFYfHkaXBHJ1xKF3XdjvEzzV
422	B62qjGmBJWG5oP95zVCik6TZJ7HfoZpNLuEY2Ddy2ZBGWXsfm56zUqV
423	B62qjAiHpGkwYMVUpNFWsM5qFZKwcQ3PVch84RSGJLsRqgjHae9ypmB
424	B62qo4K69EgaffcsRf7DzN6nK83h161wYVwcGwxYSHA9CWfdDNCL5UK
425	B62qm8JTDW2YjGCJtsSSxeX64KXzU7V7MsFdT8hQ9oHXQgMfh2Ev3xf
426	B62qne2bgd34Fayvg6JjXtqULn1YyuFYfPWRqounqx6DH9Ju9Q99HRX
427	B62qqUQ3A1c42mv2oZydLGi7GhjWEjVCtkoA2YwvCqsbTKPiEECw6HL
428	B62qqWtL6b3WiAnyFoMHWARZxsp8k5p8UvJekFRc9szrAe3DzmCMJLL
429	B62qm1GNZwmdtE4pzWJxw9Tj4TLrjdcDkckuK7ZEezC1zE8PNaWjN8U
430	B62qmcMWELkk4nXNfMYZo5a2GtR5F12Ucb6NRYwUWEZKzAciTYu8GxY
431	B62qosqyp4hdQvgU9RQ4FjVDuEiLET8NZNqQir7PyddJLSAAx6PGrHh
432	B62qqLYkYxxiC5XKZqH7kFmMU8yULC7ezqGh117ZhGnaHQPuHjBhuJR
433	B62qipdnk7eq72uKjKhGQum7pAuJGGjgxK3XcPBN1LGN2bqLZXWm8XF
434	B62qpKVMtHa1z3CGBHX6JKtnRfYsYn14CqfCuKkYhuaU7mmynGPyGSU
435	B62qkV29d1NensD3yqtkDhp8M2ZuWeShpsvyv9qGy7bsF5oHKkErb3a
436	B62qpcENWiR5VKkrHscV9cWfPwNs56ExFeb94FDiVz9GeV2mBNpMCkY
437	B62qp4kr5TN9dPQcMCXVNCnGf6GoWA5SJnLCJaiYkeKfErLN3iNYKYb
438	B62qjY4qgqZLcD9vJSB3B4We3C5N7kjKa4cfGat2HsenyYuTgPJ6fkM
439	B62qm6XTALQy15eQPvpdietiVAJ5QBU5WGRugAxRpsvbiXn6iSdNqzu
440	B62qjw8HBV8mb1qsvZSA3x4JwyJp5SG2P3cdmNXSUmUhLkzmXi8H2yL
441	B62qphi5eyyXm5wbJ3uLCL18E6BzTdTmi5AE1Ve52mHiput5E5wEH7H
442	B62qnuHogQxCbENFXYJdhyxz6dYCJDVVgjkvGxQyzxTVFN71vAyJGYQ
443	B62qmzaPsEf79D6oBr3hxAK4zYMcCRA2soTFchoPmH3TV825Dd3Dvmd
444	B62qofdXQKEMyb1CzTCHopwZGWQ2etmhwvF66Ukm4d9FkzHB71qPUT5
445	B62qpcAVHZNHsScDZZLkn5KcLVYfAZ8kdVeTPV5t67gReqS7aN3CNrD
446	B62qmsGq63CNGbBjVLdQ2hcTp5UfeNXx7tmxJbNazQaKVxJ371NkJFk
447	B62qn2545en8u3Q1UhBpSABFn1Pq3W7psprDHGxuAxw7tUeM6Veoz8A
448	B62qogRBqMKjWk9cYkCiyQVPC1J1eHBZnVbUWr8kULPmsdF5DzmKuin
449	B62qpJavug1VGCBSttepmXr6nh8fvXY5SigbN44ttYDia65vwbTEcq2
450	B62qrhwf4jRdSi4rgU3B5C5eeEWixBVbfMBfv1sEVPdrMtQsSNEdycV
451	B62qpGALWoNczLHTwTwhgxjj2qjNqdof2wzxFoZgxqyX1uaccnQ4Hnb
452	B62qpQgkdbR33itJqeUBGdyYLyi67rRZBSWTuPrBbn7TQqSaBX1c7xL
453	B62qrKhDiFPNc1VgfVVvmxwTa6oDwv4DPXNwSxC1kvY7nqYDc1LcZXq
454	B62qkmLi1Th94fnNgqKYubXTtdbcXnNEEARgMcTNcyagCm9Dx7pUbHy
455	B62qoUAvnbwKgsf7SjX1dpog1v4BdzxDxgfaVnBPAg8cRyTRvPeB36b
456	B62qmVohHxFPyF6WF5tnc6uvSBvJ2fbn79N8kRzM7DwGwp4zNtuxRk9
457	B62qkc5MQcyVGnZReDtarjR6jYa1w21EET7UfSsztKimSnM8MYdttAq
458	B62qnXy1f75qq8c6HS2Am88Gk6UyvTHK3iSYh4Hb3nD6DS2eS6wZ4or
459	B62qmCvy7LUqfZ6uZYPn6MY6pofWJntJdjx85RQRmL73jaEKpqe1Jv4
460	B62qoCnVDwSnjaQvdnSom57iJxQSeTdQQVpqV2iYCTjPEpgXpKMLFSZ
461	B62qkkmP4vNLCsYej6oSFnDCfoFAL2mwB48t3feeAG56yBKYcUJEESK
462	B62qpALMdDZqjgQEPcZhD6nuCCETJdkdmMfic6wRxJqyMnfq93vVUY1
463	B62qocryrZvDmkE9pCGQU8A3mPi1p6ixU96fgpV7yJ88QoUJbxdfi4e
464	B62qjmEiV5kBvHy2iM5NeGdCArux1dS6G3fYjy1STK1FpnpVjFf4HwU
465	B62qmrqg9A81KNuUy56eKiCQErdX9eFHPysnjZ9aMvogY2DZmGrabP4
466	B62qrg8GsvUv2GTMwrUDrWpYSxPJYFUJKqJeZo2Wf7BCodcaqYr9LQa
467	B62qq1NRi2NFiMq5T7MgAJLRzwEHYewFn4zL7gDYQVLayyZmm2CWooN
468	B62qn7Rmq7wRpMifvvXqyrnhoaajP8gkKTKEH1ippaHCn2ayDpW778F
469	B62qoCaohL5p2QTfDvPKJrPXeyJbgyBWdQkQwbVfEWYQsWAb6GaoWiV
470	B62qnreXhVb5unrPNGi2dxuJfF2NJtmbgiWPXSVHUVvi59nnGCENAYf
471	B62qmWbgvGV1MwxS6rJEG3BSbT2T8b5DP2Theb2CaBduBXGJz6qfCqb
472	B62qrAz62mfgyBUWVYpZ4ufYFgvPRqLv3vCkwnxkarG2dfZ9GCUCHgV
473	B62qmiudinE4ZbpxowZkADpMDziXs3RTgxjmiByrFmXiXBbZpXsamjq
474	B62qmNFmA2jSxynSw2hrrMixh8GYKaSgw9owhXCWo9DgStnDzSXFZhh
475	B62qnEeb4KAp9WxdMxddHVtJ8gwfyJURG5BZZ6e4LsRjQKHNWqmgSWt
476	B62qp7QPNJJxYcrR7WPraAm1zoewxS9mpNNAnYYP5WZkEdrvyaLjod7
477	B62qrjuyRWQZr89rDA7KMCtfjAx1VttWcdkGtqdmAqcMoc9Lm1GULyN
478	B62qpwr7Mc3aKFFLTAvTscaFx4sddBWSDX5my6YEBbmdHgES755moTK
479	B62qq8dC5gi1n6kxEhGUZriFe6VMkQqCqtobSUCb1x9ziyMcB1wXuDu
480	B62qpg6J9RC357VQejtdTGFwXX1t4q8XhttKGk6jMKPm8LUotLjM9Yv
481	B62qjY5YR5P4DdCa5UzCb5MaWdye16ie4ZBudZs8bsx5PJiDzS1Efvo
482	B62qpSsTVvVXnt9f8tPor2fLNZD9bHtpUM4NBwdDVSPoC4HXPaHREyQ
483	B62qmCFFVD6ynjYwjxBCUyvXbio1afrhePpB3PkhbRfu7mQAtyogNoa
484	B62qrrA1PHiXL9VnrezybVjz9CXVkJS625w9ivCmMKzKvfqADVqseDQ
485	B62qjaE41RVyhm1mcLNUwdpBJPSSYAr6MvfnWKCrmEfPz5BPRDj4GSQ
486	B62qrhLkLMHiGtiRnQkr829WuNaZRtka2Q5CxwycN7h9LV4S21kcNKd
487	B62qqx1wg5QZRmCv32jmyjRdNj6yaHYmQL9Qqubkfs2Q5BxSW3zjZeX
488	B62qppuL9myXiUnueDK8E7LNRr7wPiFKSvzb6U8qdCkETuLwd6rAs6N
489	B62qnA5mNFbeETE6WW7tLsxmFYXkJjZ9hoN7Aa4EJBwK6qjsWawpLNw
490	B62qr5FbyEhbGEAZogiGB754Jdh6iGDPcs79p8hPRtNauCt7MynmrvQ
491	B62qpsYZiJXs1fdtFKao17PJWuKJGE27nLXfKqM5jh9oeMSMnUkTi4M
492	B62qj3ZYhcFKf6rTpYkziKvzMKuMnC9QHXE9n1jovoif9rTK5HNHogx
493	B62qoL1ikYHPbSv1Z2DacVb73cVLbhjYzfyGGx4ES3y9nWSCjaTYacs
494	B62qjWj5kLFgNTyThrCdgPrNZ4sLvmZsBYKCTmsoSGrgG4C2A72U4WX
495	B62qo8EBdkFSKqs15e6Vt3PwzeiM786PmPzgCeP5k9jWEqRMYtRxec7
496	B62qn9qnWVHV27xFnBqp5Mj5f3EctADmZXTxTnPXzkvYUyhg5FkjCVW
497	B62qrTTLH4VxCJy1nNYZMV9XhXAtopxnQ1KXZbrBWj8zLdzWSiad3gs
498	B62qnE1JLRhrYRoqvuwkCdNui1LpcRj5H29FptwbUQvau7xNMEAcaf5
499	B62qjYFuUkb1D8xgwdADbiZ6UUr6KA6x61BzzE1K9sgemawDbytmjTb
500	B62qqja2YnsyBoDvMrpkHFCwJpSjEn47biEhm4QKZEUVFBxQZYZmv6w
501	B62qqRtCkFNBtAzB9D82ay94iFxU1RCtTXYQ4miqH6xrTiwEJ25T8sR
502	B62qizFZP1uW4PEWii46T74kMEmd5J26fQgKs3V69CNjVeH4cWk168D
503	B62qpaKdUrK4mw9BFk6YrEtjkuZkg1yJ646XnD8iPsSkV3FFGBjNdvt
504	B62qoj4NpnbGSLV62tu2UbTRFV7Ec8kYcQW6H16BfNYhHstBMiahmbi
505	B62qrP5fybkeKbRpLRf2CFmnAjLEnZf36DT5CT6h8fMtxTJfYCzXqiW
506	B62qm6SbSHyyHBd864eWQQn3j9XPLUGQgM745oyaPBesvQbWAAWZShZ
507	B62qkfbG38SMsrVyMpFb5KkDiSLsgPiYsodKZ9UuAkmNfBe8Gus4Hsw
508	B62qjwMQC1yLPcv6Cyog1j4qFiynFXDgpvFX8fjYaFR3UJtD6cN8ErD
509	B62qkxwU5ePDE66ChRww27pGA5dmtXK7prFaebVc1bJc2ttnTw9Mi5k
510	B62qjLzQz4Sc8yu1Ykv31T63XDCAYLpzQg5tLeHrii9zQ3LcDgSW3fS
511	B62qkzeJK1ou1LtGxq94tY2fTy1E4uoovTzDpSAJzXZLfaDLjUrcC2x
512	B62qo8no6zXZa68SmhqtwtSoKtztQ35oT9S6maRPocuu6jkBr7JWMJg
513	B62qp4H3V37M38xgN2v1uTg55KPn5piTZbfRv4yugp859ognNRd5NxF
514	B62qnrx9HSU5Dwe9G8PopjFBdHf1c6rxG4niY8P4CHfnMo8bJPGo8jo
515	B62qkCj4Tg7CNecRfDryTUBmc6gwFQgvBD7Ea8bz6ELYTiTmuJEEf6D
516	B62qkZf4qaDNQSvA3qLDHhUEUyrPUyB7wB3uNafWc6a2CctakqxQRK8
517	B62qofSBi53zHx4dLsZxh6bcNu9MECsUBdZH96FrDb5kQWNac6nQ9Ys
518	B62qn3eMx3ZxS1FQ46wepgTpX7JG5ponY38f2wovU9xGqDzdnBD5kmN
519	B62qkAubK8h3D8zG3DC33n7W6u2pPot8HBHYA7oemdUGq7o4v3gE4DR
520	B62qriA1rqpkBS338FEgr3Gd8jL1tqxj6d1Vgtr5WH9n4YRBLrstE9D
521	B62qjQ5cHbShm31do3N9wmRu1AVDBV1AaAQnxM9VoKq5aV8EERtnYB8
522	B62qmEmc7wkUTTgcFEN4JUr9Up439hb7QZDPA7wBhHF83fAcCuYkoCJ
523	B62qpNawMqmLVq6Gc8FnqCYSkzqVquRigZUW9VNKPc8CEZxJeus9c96
524	B62qk87DbSD239zGYdh1sTTQunnfirm6H4TjDxUm3gA768H4XSLctAu
525	B62qmff5VshnR73TZ4V95zPUNZbNNnLqsG6o3SYLSAEuoX88TfYdtCs
526	B62qp4Gwy1ZxVA6EhqFPJ7oZphYKhuJYgVdYNkBUQEmwhY2J7d311Ys
527	B62qj74mCpk5sbvHWobuq3Q2ybZYvyNtfPcSiEMKds8HAbwtT3UhiG2
528	B62qrxQZJQq1kgcKC1QhhPYvfJD6rizW9vFc2yL45axKRDnavjpUY7q
529	B62qjohg1jbbiTpQNzAgi8NLDnS3L6H9Wsz6AEuWVdRCBDNKNKYXHmG
530	B62qjJAwwbXg6kXPYHzMTKBA2bG4RtiYggvYdCJVQTCB1ArMerwtzzh
531	B62qo3VjJHcjPh8TEzWXajHfC4pXCHisnHEaAajkHEeMTQ62XYY24KM
532	B62qoXNSt372178kswdiLjr5BQZ5eUTx7dzebbCqKzxVjLKEEEPkqxm
533	B62qq2PGvsoNC4u3uxthhs2ztXzuXRzqoWX9pWUDo5xdC3vdG7DQkjU
534	B62qisVmXEHZy9gjmCBrpLNTPp1Va1tYyFby1xV8hnNQvUZdZpq9Gmw
535	B62qiwepAfGCvyDBMx8acQ2wTwEDLN4ZkAK4VEwtuDqawKfvs2Y2Ej6
536	B62qod4Qzz1215F8LfFz2tmAkWtT1S1rmrfZs8283NYm9tYPuLhPP5d
537	B62qqNTecEPfa49JE3XLTVTvvzDfkqQWCLc8TVC26sGtmwQkPModRrn
538	B62qrfRjSn7Wz1JAyM66rd46Zcf37sWa9tobyXh9wfZubHEfozW3SAf
539	B62qph32vKvKjNDkpYdx1aUGDnM2ZT9qJ8d1vt19EwuL7yKyaLprXCG
540	B62qrGa2DAehUxo7Bhsk6hfoSLWL4kBbXtT3hST168hRyUkrEZwbCnf
541	B62qm8QwMLApni86t94X2WmHuxspzs3cbB9BaBb4dqrt2gzMEGXhjQe
542	B62qm49T1qENZyPSJPWPSc8wvpWMb5JjkChECazSdcxkE5zxXuv2Cd1
543	B62qnqEqsuH7kST9ZrbksRzihXD2tgHfvq9TF73XKAMj47gisT9xsJ5
544	B62qkaumutxogA7B781qgAYaQdXwr6SLp9dwmEfKj8KB3LsDtWhpXhm
545	B62qo463EfezM6wEYX9JVMT787XezVCszhTg5f2Pb6TbSds7jyPg5vd
546	B62qmMd8zb4Wu2MjQSCZvGB9VoiZNTXHqy7aQp58AhpiE6wTRRpAQ1H
547	B62qpu1rQdxNjwhXQtL2BA1JefpMHQqfmhmfh9MbTPVpijK3qYmGK99
548	B62qkYdFy8bJQYJ5JPhpFYuQGPwEzH6zKcpFyKTwQaTHPMk8Tmu7J67
549	B62qjPo8EuvgkS1HuDLgE7k9WWnABYZJXxTsMystpVktR8pDpSPDxoc
550	B62qoJgo3ZwNZJ1CJfQa3czHHnTESM1njEmcwuUzudMspfbY86TkV1f
551	B62qoJBsUJkxSHHhooLdgmNUZS9ihA3NXhN1KtXY43U2uX58MNqRK3u
552	B62qkjHJXHXpqrdVsoM8JPQ9CGjimZzZzx73Wth8MyNyqmdkEMdGAxo
553	B62qjtckRzJvbYjn59snWWakxvuBLTwvEs6YyNxUrFDm5NuTggpXaKX
554	B62qqy81eScdUWUvXiUU92d8ZpBdCKEo2oCEKDqs8yPwKzNUByf1Uo2
555	B62qn5eK8hgYRpkHAQcmfxbbvCsXk7tYAmGiqXBHK5dzRN9k7uL55Kv
556	B62qnGfRHkjXCF25AguH3EUJZzDNXv4xrFM9Z1Kd9a85FovbR25js1y
557	B62qqUbtYZCczK9pF3f3XtmAceSiD1tXwkjwQCT1o93X83tFU7rcrz2
558	B62qrYD5oqNfvrFP84wcgEx31bSDCib2yyx4S7oy1ZQfB7YuhpPeykL
559	B62qkrNfQtiW9XAo2yqscuJ9VVx9n9RquwLbka7KetHEwp7AifQLHqE
560	B62qr34Toyq8idNpPsPBR1dhgjUdTXKAvnCBnVt57eh6wDQ956aSPLh
561	B62qnXGNL44878HmkoTvkmjDHRxReHPFFjBcf4qjWDjUxjMoLmuJVWw
562	B62qr6nJMF7Abm9rsW2motSJqwmuu5ZeAHJcESgfnTXZZKJXzvMFM3p
563	B62qpdPvGHBe2ceij4GEZYAarqTdrWEi97trdZLRBoJHLxu1W2mqBG9
564	B62qrUXUnrc1tR1XN44eVaYVyw64MYD7p841LHsxzuMy6yERkbkzS87
565	B62qrAWZFqvgJbfU95t1owLAMKtsDTAGgSZzsBJYUzeQZ7dQNMmG5vw
566	B62qqom5m5YVX2dGpJV2pVPGQP7HKDCnXBRd47QKeTewcvgAFfjs7ay
567	B62qmTYWQUM5V1r9HT5wVPVYgWpotezECEgciGAXJFFGJKzNZpzH3Fz
568	B62qkUDWTWF6jZ8DxaZZ64JrFRbBgdNrRmfKricno68TmFjkxMGearM
569	B62qqSBUwbUxVdhKvVNtkWT1rkMFkjmd8cGaNGTrgN4mRgUqN73HjBr
570	B62qqnTQYi2ZdDaeePDxmrgcporgoFMcTMbxPmzpwQn31VSXMHawzyU
571	B62qkqNhtDFa5ZDYGrUqn9CEB6aGrgMyj1JLeEPX4tmM6cdWnrH6rRo
572	B62qisRXbV3EMYm4aVEtxevtG242pXpyzgHnxMhMKXdRZkJViRyQ2EE
573	B62qprCAep9orCrPMxQ7foJ6yP2bip14DbHNnzb2ia3aA2mQ7uVhrWp
574	B62qjzTb39cVFyaKmswTGBnGGKi8y8DFGP3KCoYVzq4nSFZPZdjoYqN
575	B62qmnWhJ5s19tza9eASRaFNasysrFKcmWPq9FJa5NYSe9V78FUuVSt
576	B62qmzcyCKrQ99WsXvG5MbvM71XveUkg7jVcoMVVwTbcQWmRx2iYvH9
577	B62qp4jr1PgwK42Ah4HG2qNHigTw5riKFr6RprguAX6ms8ArDcdGv7a
578	B62qnrW8QqY2K86HTyWXWyNzCUggHCbyqcU8DyUSYNoL7TirEFeBrFN
579	B62qjjXbygJnetM7hm8kC5T6rxTCZHzQL9SSxDaQopS6fVLwJUNYUan
580	B62qjvYEMFyGVaHCXbfRXpvr3gboQzQTZUpPQunEJRpgLd48pNX56QX
581	B62qncFkdax9ZsbePo2H6wNB61ZVrEQfiBszW2KGrnGP2QQHj3kJmAH
582	B62qokFNLPLZsP4dS1ama58fuCdqR5eVqSVYhAqixM9V1eS1nfeJmqQ
583	B62qpaiW37BtfN2LF9mnLwUucc6NSERb4g3LwAM19GS2Bg5eKWYRVpi
584	B62qn2cHKQ2B3yMFm3nPGZtjjybLyNV4M6cPJhU5qwJshboM3v1gGjL
585	B62qqn71PnUEPEd5dSVqLhF3ybFkrLs92Zp9vqNtzSChozgQy9LvUbr
586	B62qpfNHqWHttFwaQCoG56SFsTNUkiq8ZSCDh1dUHBjEQydvnGrps85
587	B62qqWpBYarX9Ly3YgQVr4FCmfNJQ5h58tB4tUeWk6ahzUb1JRQC45m
588	B62qjhfxnFVwmeeM2sQS6JFNKqQQjU6vh6aRx65rj2kLNYctTwGNZ6e
589	B62qm1aBGdqZBX978CTRL4nXsZBL53vEVN89nWXNqD3en3GTkBdrVt4
590	B62qnMBhchthufETXtKFcmruhGth4rKpishTyEthEWDstkKpYv3js1E
591	B62qjB47C7qpPBEa9og3QcPj7a89ossecNMkKkyWJSYNLBxEjAcjT5t
592	B62qmN3QcipBRd1izGrZqRHrdCnrXLLGW5RRoNNG2kCFAf2zr9UvDUm
593	B62qjcaDeZdy1SdJ8DM5EazXY7LgFYumPE1yWwwCTr18qhYJmJ7tVcw
594	B62qpGyTotKHjKuT9GNb9SG2gH44RwkdpzfFSpvrTLTNx77onpvwfpE
595	B62qjET9m1YnNPcgdFZCBiacwGAo3nXZY7GdLdvVsa6cNCPPk5FTc9d
596	B62qr8FNc8n4xa9tJwy8jmmahpzzmNxG5HoEt7RnJNw12RGTVVbQpBn
597	B62qqgGAQfpFhX8G1iF253C37CMsj6ypn77C9fr3Y17iU6B5Ft4XjPo
598	B62qqkkHiZBewA4R417fKmS3RjehKszHLWQeMbB82FC1mzaQC8Ug8eN
599	B62qpuwoWLnPxHTvziz5BXWFN1YHEMMsgvzxs61Cfvp86Ug1Tyg8cYk
600	B62qjREKDBtm5KBteU8RibX6P6JLnoQifWYL3KGvaRLJjUTb2WM9hjf
601	B62qieizHWA2zusWh8y9eCzqA6dvgGNSs5RJGHPmAGcBtdgr8BRSfEg
602	B62qnYnbEvsgp6XxhniNMSJWA43S1KhWFTa5yj8eNxesUT4oy1SC7r3
603	B62qruUAtiAwgCWccA8ar6GRpn42XcveALEFLqFtZmhMcv7qMgypXZJ
604	B62qiU5Mc96FNQJQwv8JrE9LB8RkvummZ5MKnWTPCiY2E6KHnVppujV
605	B62qovmdQfDRrVH8M9VcjZtzDBQZLMs4hGUHa2mTD9AqUBrVdhbdXxC
606	B62qqUbgYoUXC8kBedrGQCkJVyVc4dcS83wnvnwfy7hrcKhp6tTuij7
607	B62qqpujuZ5W9uGtEwJv9R9yP8475hjFd93D4fVXoVPi9tmAMsQZBhn
608	B62qqSvXBa1cdTsARTVZrnJreCDdEy162q7axsf3QfjWzZCKfrU6JoM
609	B62qofuCX3tvb3h4TCQtRpVkm48QagKxPduDqGeTerYrfnrqPVHJnvH
610	B62qjbquAf4aYaSDycp5LRghKFgcHN9iqEVF58HDToC3khxeWH4Sf78
611	B62qjVmBp2KcF8ZNwXWrmhLuUPmogYuQBtfHEhdoaPZee5BUTJEWkku
612	B62qmQ7bj2w7PsKUkhicKKYCP3FpaGRExYVZm1EPLrniABscEELzgSz
613	B62qnWVQwpWWygmtRhdKwXqLoKrK3NgrWH3tA4E2EqUxw78ftmeG54s
614	B62qoWWs3NfAPtVKRnZF96gEF3MWbptg9bzC254AQNswpk9WwTFkjS4
615	B62qjsX96RP1X57eLLFWtZ7KwLonopTQ7ha99Hbt4wkyreFHkh7niCk
616	B62qmLxegnngeCpHk3DhZ3o2NKBT6v3oFSYM5S7ZnVHgTx6RMcEBJyX
617	B62qpYeiM61GB1NSuPxLyiqnXQSJCN6tLzkKuD3sr6Vs9qauV67zNiS
618	B62qmMmwbzrAD7EUmGSHJmwxhRBXkDxqRbudLf2p1ediX1N5zcifWpY
619	B62qoa1oVv1uEUUPyPHDc4NHxSb3Lw3XEV7GPcwwuYd3vVSmVV9Jo9P
620	B62qou8psL2pgHjKtNaXneRq8FJWjjvbxHKZVhR5oQiu9ea5MPpa9QW
621	B62qrCS5D3bvY9rJ7QLfkkiFF1Gq3S87q7qa72d6VbCwC1UjwxykHTF
622	B62qji8m9VLx6nomDdE8aiMokRfe7U4CM2wnbsVQjnuVKzjE4rscboL
623	B62qnUwVMUnPEjqLyuzoTgyUF7pXZaYYahrkchgB5mdY2mc6sbq3aP4
624	B62qmHTypp7EXGMJnZXYRpHEmRGyZCTpDgjSmkpmQa66GQqR6eaGode
625	B62qmkCaak2xES3VorJkREWQEGiLVSJJxZp5sCVcRXpvPBzudwcyjRh
626	B62qnhc3Ms4pDmgU4jR1GriwCdWvTeiKcWo1ghvAinQn1kmjqMXFpgn
627	B62qiiCieHKamGw4VWafNQuS9Dk5vRpVV4hfTSa7b5QY8DAHd8DsTse
628	B62qjCk68N2Bru3X2qKnGbzSXeAcaBRKHMQ8AFtjzsV51U2ZeBgsMbV
629	B62qjhoGN4uGjHGV2nuLys5BegEU9ogzk5M93SixvEe9YWju4r93v5x
630	B62qqUCg4rwxdbgHPsZ7Y4CViYsFPXqdNheEv3PG1AYuCtDmp35gviB
631	B62qk6cpqWZJ8tAk8pWJXovNNKaxsnv3vCiTtHSr7SCTfHvYtesLWyU
632	B62qjmReWEeTVAM9btVNBvzs4XPod6SkCAw73t1pJnLddrUg1cP6FaP
633	B62qp6qMf3Do4q4aKqEsLxVpVuXJaRCijtyhsjZBvDSEFUBGXg8Z9cs
634	B62qkbNu6GyDJ7uxXkfYQiVZHfomjtqN71sRcmt16Dg5VdjWBcuvJRK
635	B62qpMndmJbN4GDzfcCs4Y1Qk7Ss5ggB3t5JujqR2aco19erjZuwTSS
636	B62qnYNUymzFsd2Qn2ofpGkK67N6MHySGyVNK6c96nVAtqHptrt9Xin
637	B62qmW3eMFnZkFPEkqz35KvuRfEJdx4U5PydcUmbs2P3ioV8c3qZCuR
638	B62qqqEiUWc6RsMyJAyjzao4Ba58nN7mb2ETjNNWpWCQtEzsd7sJwoy
639	B62qnzzyo6V8Tp2uxgGYJ5DGZ6oKV8JWV4NgkMJrqqCRwqEu5dfPaLu
640	B62qn1QgqkzTVXYqE1XVy24znjMuNgixJyBWQiFzEjPpRYHaJMsQK7b
641	B62qqF2kUvSDw9r4XdukwST3qtqXE1S5oVfMidV4JBr3BFHpGQ3Pd4d
642	B62qjw2PdqLJYNTr6cNDXEmnc9FLNoaqVMHMqiTX7sqLYJRpd3mshFA
643	B62qjS3YrJ3X55jxEqVjC5CbKRp3XF7SpzNvW3VENGMFcXzdEgSDx5P
644	B62qqJ9zVibqkZob87KoGUuXtHjbJav87soLvUWmDbGpRsfYdToqYgP
645	B62qmG9FPKEZJbm6vE7nMNj8pvTzN8Rra1L9rRNhnwV3VJceHzg4SVA
646	B62qjVQXeEbmiToTf1ipPd3c5BDgHuqjzb8GCxdgFuaDV5EGg1yMBZm
647	B62qr2mdhKQAJb3nSwHJsvubaexz6S41PHTtuDbvqCgp7d6Wx9C4A5z
648	B62qptcZgqZFFwkkmbhvjFiwac6xj8ysCbzWkVTYzT6NckRKTpi7KH8
649	B62qoiUvWG5EpEPHTqP1qdxmyteyu3r7ogbjDyAjntWofNGVqfFzznU
650	B62qpqKh6G14cd8HdnXw8xk5kZhRLywjJkPChRBXh16J69dtkWhtw1K
651	B62qoADxfYFK8WytE3RK5vH7uYYpsJ6Dz63wxB9XFJjJkzRBctb4UzD
652	B62qrnPdz8HpsDJfGHirDLpVrN2VeyeitdaTKBaccWtHpeVW9Hgwi75
653	B62qjwTD8QKpffkzNEvtJVqRfK9gT1APcvAu6PkV2nD4PLTbvzx9KTM
654	B62qjJ8mNz65hUKWTh5wYbaHDa9nqfhz21JbY4ts69xBNYhTQxbQzCJ
655	B62qkwXAkimjPGatos62oGuy8hL6SgPN6uwnts6NHMjJt8xREdFTgEh
656	B62qpE5W2YYB7M8F7SPUPG9BZiKMoYXpv1zNFbgUCvGFWXTAuxdFwUs
657	B62qrRKJoUsaKzv82QgkkrVcq1iPCprxMACryScmgFkL4vQLeseoLQv
658	B62qkTNiWzgNBrnmFXVobwrQqASFfWkVxMGzWH8NL1fDc6Ckwvf2oG3
659	B62qkaLCKizSR2XFYFK22jVPuxSjJKXPhm8b9QxsGmW5K15eYFq7ZNH
660	B62qqqhi6Sy7StZaT7FGFn4DQaRANEkiQfRSdnisCoX5n46HD9D9tZK
661	B62qoKgbZLxduRtXiWrfM4zhmkicPQwsNtd4eqcizd7WPwD18aDH5hj
662	B62qneDu6K65UhAuf7YCXADJWtgJh1y9xk4nEtGKggLaTr2M3Fbj3iR
663	B62qiZwdQ8Wdk8PuGtdCNzWrK49zmxLFWmogt2xXNS3y9eKS7o5qwxr
664	B62qrGdW3pGKhs8BRGrjom3WzTFShfAobatkyKwqw7Yrn6NEYDDpH9C
665	B62qmGqivW5t7jsKRooqzAroKYSA8vxmsreEeMgxMWzzjdjUtWY1LYx
666	B62qrotmFVdZMGL1pbSX7PZUWKJirNg33bFURd95e3rpxMZkg8f2T7h
667	B62qjygKzKjrqscEqYNygB5HpDpVHBGP4QQ5uYar68riyYiJfg9FvyG
668	B62qqJwQJuDAUEcB6gjj7cDDhG12G1xwQcNeM8fi4wFG3GgSrz2WyL7
669	B62qqg8tqdhUx9K9borozHQanZpRs7zGPsRZYt3tXVMuuMYjUtaCvU1
670	B62qqrzb7RF35uzzoxN1aGLVmaHpF8MfoD8wrB1y1R8ve2DXZtVHhAz
671	B62qqGW3z7MPqw4jDQrYhUHtq8JrhFWDghAyERWteu5CJWzHkTkrQ7k
672	B62qoLPVcqSf2pKoc9cZnXF4mcLh9Zjtk7rcayvwsgWuJTGxiSWtrhy
673	B62qmGV3ExCGJhDJRH8eq55VsSAJoQPBnMt5rmG1SUa7voPLeoLbBJy
674	B62qrQVEMzZSpnfZsDoTXtFNPcbrAogL22TS7pLam6Ex9sDNAG6pCYj
675	B62qmdut1usji2NFZSn9BrywhjHakYtAvL7Mdy7muyjcbrY3hKJ688Y
676	B62qiZktgNut9AdNXZLcLQSFioiaWH4grePCtfsPnmkcxfg5q2MjZK4
677	B62qpBGfLWyBN24kRB81tZHQ1n8PLgdvABemUDGJU2Axp6WMY2zBYUQ
678	B62qr6SB6kaJAmAiRrWkFoHN9htKh2j7H7UZ3uyTGxtkMXqNqhTEZX1
679	B62qooHQvsHsqfudGFU6wcK2YfCz7EuUd8cUT9qxfkEbt5uvTA4481Z
680	B62qkHSAjmBUWhjqZ84GNX5rnWFyVfdtBtfeeKm2D6ANtdUvfFNWQac
681	B62qqBjKoZYj1A7AAigACJZjwr7Fx2wYLGwc4z7a2WpHhsxfLu15mzH
682	B62qkkAEbwCPAAPMZz7qKP33yZpUUr54QbKs1HLVRkykoUj7SqLdfuY
683	B62qnPR78Ki1fNeANn6BBhEJByghyYUMBDiQbWVmrUMMLezPo3VjUMV
684	B62qqQ7Ucs5uquPTFgveJcN1fnHCRehxnWuVGhV5GjNzQPdWsWuH7Nh
685	B62qs12XTUTSiWuhyF1R3MfXB3p4QaGxv6JFZYoMUuG4DGCEhzn39LL
686	B62qmcuVwrf9CVBf9AfEatVG7PHr4YRYV7LvQt1GDu1ZAf5wUxvG6aB
687	B62qnpPdwJVRbyvvLkPAWYGUbkA7NUZTVdiqa1B5oEd8ABSf6YDhVXa
688	B62qqneFCrrHKdvQg6tdKGjgpJa28Lk3basrGPkyZfBJtjgocd2eabi
689	B62qogWqDwAcZVwXteX11RTtBqL9viVed1Uot55QGeoMx5dUnCVcrZF
690	B62qmf4xKkMvEA2jqAEGe2QSs34KZzSdNHXuRmduMNy8ix1MWYWacme
691	B62qqkhvx6FtK5D5Z7K1x7ebVjoxd28NtSCRacYTqueWCWQERqtEDPb
692	B62qknwJHQU7EwT9NcvUbqwq95oHx8fFMQiGpEeiq2hKkfKWor3zdnQ
693	B62qpXgAyh96eymS5ysvnCMyuQYT4WcGq66NsWgPciwE7GgUYyCibfG
694	B62qnnJz9t5v9qwLnnYg9js11RiHBTZWxg1KkJhmnAJ1iBoU5MDkDNb
695	B62qpaDKrgPfyxZtxMXZF9CpsYcVxCFMofG6dWm5cQtwTL5LzpxtHHy
696	B62qjRjKBtAr38kh8rVFytHcWY2dRRyF23ego9UjKeqkQLX76sB4FAQ
697	B62qp69bsgUNySCY2wEYDCrRN3gdMB6cDSZGBucTzc9vUUH4jUoDSED
698	B62qrJ6V72vUoqTnJUsXwBFbCU2cCk42To4mmRRY19NiGMZqJuYLLJP
699	B62qpczQrxYHA57A2eSmeSPZf12k5uFZhzrkNZgViDwjfnVRDkdnpC6
700	B62qqAq8DqCN342Em3FfZXZV5g2dK3tgtgpt75HvAyc9sRHn3q6wM82
701	B62qjUaGVZqZ8iri5r6rSQya6a1jWqyYAQt7JSicLf1sQs9BRCKdskT
702	B62qmT1gn5equzmv5LtUSR7uW1ST1d2mCvpgeWcN5DKGAJedWFVCSN5
703	B62qnr6wsfZxsxFk9xEZvsgKTLTmFmd9czVieRpEv4YnQmHUaVMMDTa
704	B62qpJPsP9ef7vbgtwcRveQJgAsWKZduzL6BAj3k39qSpfFr2dxB2io
705	B62qopxMBgKZehZ28XCa67puBLdaFJcetetQ5Eqzsov63t9G4frjJQe
706	B62qmiHLHuXxGC5fcy1QqM185VeW8CN3MZm72d2PraRNFxAzzcQ3K8c
707	B62qmfjBQ8xtj4MfcQA5kd65VAp7usta45qmowjMeNuZhvizAxYnoPD
708	B62qoyHpeJHELgZGhECbCQ6tn5gHK5MJY8RYUi4UYaf1B5oTTwjMjb1
709	B62qitBtpsUFVthx4w8pWXTMX33iYm6hRKEjsN43QeRuieUfwk52SbD
710	B62qo758VUF9BH7kdmzxvchdQg1e4DfJNaDaLubdMYTwjtKU48NrTsU
711	B62qrAjwKEug5bXehb1WoxPrDf7heb2VSy8yEmKHVp1dAfseYHhBmfk
712	B62qrSiA6i3HQRDS2boxepfMaXQeof88YLTJBEr3qjCNZerNfrZkEYs
713	B62qrHQbB4jYT1oCtbX3V37GvMSwPSw6oYmYFPYnjYNLdc7rpSdkERD
714	B62qreGujxwhvS7FM3yLHfHVUnkrj5KSWyQPkAz2B5sYkFBacvboE4R
715	B62qqP9XWKj3xMTxXrjpUR25d8k5ocEh8fiGxp8C3EszYHLuXMUPCgc
716	B62qjajZHX3V9boBnG4gNupuR6EYbT9racDtJC1GHY6bThdyHe6GGU8
717	B62qmpK6T59DvNivKs3zDXNcR7FRMQJxJVW7h9QimNjd3yegAPxjknN
718	B62qj5xvECtvu1eWdLWWHkUUULbkazUL2kRJZm1hkgwv7N8KJeE3GsU
719	B62qr7KAAzUrv7hkKDgnSzz1xDi6BuetvDrckQxtz7GNh9PrENkiH1c
720	B62qkoKSrcJms7W8HNvFteypzAYLdGMoe52mGjzx1pvNRLQLX6ZCqRh
721	B62qp48Cwkd7MpGfQBbYkUqpeeRhT5dDfW7MUBYH3zgSuwWQPpBMbSP
722	B62qoSKy5LTX48VRcvVuCfWLMeuHNqsqPZXXeYwHVkxshneaeW1rKPh
723	B62qrBcgyttwueJWQDiYA6r8PQ3X3Jh3Fkn6Y3k6XTDehoR9L5kQ4zG
724	B62qooudywX15CbVbZ1KA2ZVMJ8aWqCvYKgYnE36u8qDqZsXkS8psyk
725	B62qqDvzvGP798vcVLeGczsY3sKypYTfhk5zKk2sNyCPx9kWBkh9Emx
726	B62qj2hYKc8e6ehN7V2x4TPR1M8NjKaJZRR68fHLRh7D3BRNJSXnNKn
727	B62qoYG6v71VxyYiGERuReb4V6etLF3vdzryEXQUHWiCSz8bsaA2qZA
728	B62qpSnqVrNamS2jT9UJRxUTWajt1uzamEb9Rp6AztWiXnMEeooP5h4
729	B62qp8dFx9w5si4QzcPdMmSqFd55MPgNJiAsxtsYCzRYLGvV4XDHXXu
730	B62qmDfmcUqZTwxsomFzMBfqFisLS63VSsfyH8v2ezwh44sZH3KkEHA
731	B62qktozdEL1KySmBrr5kTZVyjcpoi74mzK3tshi2qXptqeuX56DY4m
732	B62qn519rweP51hpDGQYqCZ8JRPkpxHd2JzDoBFQcupGppuwkpGBHp9
733	B62qmEorLV4gifAPeg4GoN8PpTWEr7ytx8Xejazc1skGepEALxEbENH
734	B62qnTdTtkepo2yfBXCeMp9afk77oo3EKWDNWuvLzEHSZz2gkgr5JHj
735	B62qiuqZjBn29vKLHgDffoyYCzvn3iqciQd1LqtMKKii6VJgZfM4cTm
736	B62qnjzqEn9dxzz2e6PtoRKipZWKToySCQbKaMTjuyuTdxdmMCHGjLD
737	B62qkkNzkCjbwhhEtu1HJ7SuEezuEzpkdUCfBrvo4vtCVutiTtECS1w
738	B62qrUS2A6sjnk95D83g1sjAryRBDwjBWhBdzPKZJbgoeMaY1YrHnzQ
739	B62qm5HhL5ESWzGMBRdzjVkRGD5ZzAf8YYErcXYyDbSy7o9EXUXMqnk
740	B62qkwrHj3YCKgQsXRktpwhVFij19RiwYDgMmiwp7iggNBi8712a4W4
741	B62qk2bwhv6KNHyaUjC4ab8XPhAvDDUByaR4dGXqvR8d7duavJVNq8e
742	B62qkx6oy3qGwxaYYTeh3WeUZemaLo1Kqyui9io6Y5wxeJPEWHEVey6
743	B62qobHLtqcoUqhpmpjsJQNXhfUTbKyV4Ug5qJWV8mTqtbZbJAmn1P6
744	B62qmtWtBjJjBoTrCGdTop1uZqmf7b3nnY1RX48hXUy9XkNNxj6o5fH
745	B62qmAuxm3DoE2Mp5doamtmKwmD6TGmeA3SPuh57bvH6LUcZspbaF7b
746	B62qo1EYgARevAzQyNDxhNmKwZAdHg4j65Sr4JnJwtoLGXt6ustog1n
747	B62qoeJgVm3MzkQD8GiHNSFmEcGYRT5WaAQZ16DFYjcE2R38nCsXc6A
748	B62qj4odmzXgncnBCmBQ5CGoaD7y6rPTQC3qNezGrw31sdDqxbTzRab
749	B62qm8BBqTFCc1KKiDU6wuqjZf6n65dasH8jAHSrLZiNyzhQJLZUizQ
750	B62qjHdRfaxSdUkta6Qqa6oiXQ8WnRGkMa3rDuX1e9zZTUHwooQ9wHy
751	B62qjShUd15Mezic2rixrzAfJ9HRDQKbWqSoocLMUqoLrGVv7avL8uq
752	B62qmhF6ip7xWbEoUSUUtuvZno6itX4bTfCPoAfkmjAbv14XJfsUMgZ
753	B62qq5W8QExpM1qgMitciWQghnEQc5Gy6y2v9rEKEbxfBSw3Hh5NgHW
754	B62qjD5F3fYFhRUbdfrvUzuEhouPX8zgxDmRKL39oEWppJMRuhM5uGn
755	B62qkY65gWYLm68fqW4nKj8URcr5BTb8BN5UHo65Dkh35tDMrgPeyeH
756	B62qqdTvDUeXvUSAUiNQ12BthhmgLDpXUrmxzYdbHxLz3dUNM4vEt4Y
757	B62qpeTWsqipUEyG6nQb54SfbDrCrzK5zBwFoVqggexDNrUnV1aXAdo
758	B62qorPGKrHgPAkt2FM16N8JttM8CrYVwL15tBy5oigLESPFYC1SyXh
759	B62qqhmvrqpBEJ55rR6v42AFnh59KktBsXBqs4i2fBVTb7uBqBsUNSy
760	B62qrLdrRjY339ix4YneW5hQwXcaPFYbL4y35VEJUKoUugrv6x1DAFk
761	B62qo2eh5weVKJH7AtwBJewA9rKKwPYeScV9y5QgJWPJqMaYuc6kQ7T
762	B62qpV2bk8Pge5E9D2JrMwg3ZTjZ7G7YKH3k5Bmo1D33yhiYgu92Cn3
763	B62qkL5VU2iDpUgr4rqkGiu1PaYspDnE266618gUVmpVnARaXbd7iiB
764	B62qpW3zh1yMd6n7bkXuT4SrWjEp9bZeDTkY449DMBYBSjEX8wJTy15
765	B62qmfZo5Hbs4iJ2edczgFJsbSnTunDPPaXjR1AtJVX1e9DHuezeKXg
766	B62qqsDZB9aHvRqLGzsvMzC1ZHewLEkActsP3VFRBBdGabAdSrgMrnD
767	B62qnMXrsM3J1pjdiDuwcem1dZeRtn3aDDyr19fTEcAbyaxwyZSWEuN
768	B62qn4BzvXMoAxWPpRf59yjgowibyXBhcUzGZJmCJ7RRUaDwDdxpq7G
769	B62qmQ4WrMAxMV1tBjANXZiH1FbCwhhsR2p3uXWcVbRQaj4bPTH7fGj
770	B62qqoDxUHd2E3g5Ngm3HphxN474YzRwdSVyYoNnUo4um5qGxLxtZ9K
771	B62qmVHYfw8BGCpw6ngZcM4tBo9GFeyRw952N2WB1LNaGZEtGAtFBFS
772	B62qqCFf6pUfES9zA3h3t7qTezP3RJvYkb1Y4szDNkQj9LuYayXtkVU
773	B62qmT4DxZoFZqJgfKYpZaHyV8KBfkmYCuGTKBfioKd9Lddd7HgeARV
774	B62qjVUmgXQikmcey3JHSF6fVqX7MoQGnDfaNu2AQpka8YiKfTmggZe
775	B62qqDR4cmdfXz56KDVG86TDvaa2To1gDxh4XPXEcPE5SEZJTawznVA
776	B62qo76fFxJPC7zGT7NwpZKDVuKHnLYURfnvHVXzWU5zgHRCagRyZfQ
777	B62qr2ingZ5sWoyEPFazcQkYYWx99mLqs84pPYSdpWkRCKsg9Gz4kTz
778	B62qjrj3SdfDoWxS6WvKn2Tvr7mdA3EtbsHioUuXGL73ckHu7iDcfJb
779	B62qq7uLzNiVPAsnAzKjkWQ9dviqCH1FbNZcSz2Gi5gnjoVoVApgMdC
780	B62qjb4fDewKhourt5S272F1WKzrvFVBvCz6dthVErR3bVHpfNL3Q9r
781	B62qj4UFkH3x6rKf8KVcbuPjGQhxDrwcaqUYiMNJk7Ct9DB49X6pMBP
782	B62qrBYNNHZSLNZwaY4FZVNkesEPkFbZfq3YUTa4ZyqRkz1aN86BUFN
783	B62qjuZfx77kQYKa8WxE11MdN8kT62gJcoZov68wTwTn4rizgCLqtwD
784	B62qnnpwVapFcMQmADmxEEP7FLCQJFVsWFoszPa9j8XMANR3bdBpDyg
785	B62qk3gczz73qX3JJuKhovf6kV2F4jucX58P3Jgiz2wLB4THjgGMfAg
786	B62qoj6Fa45LsKrCiGRTFCuUued9GNsRc5yhy99Du1i2ujk58qUL5Gu
787	B62qkHLU1L6hu4kFvewrczukTf5xLuT9nEushCbJUdjiaUUwr8PKE8X
788	B62qpb5mxHwJGQZt9KvY9m8NB9Ys1noCZU9zVjYmfdEezE6dVbBdnjd
789	B62qjy97FSjL6v6WwLBgvkMqwq6GriQqwdcsw9TWGUt2heoxLYn2fc6
790	B62qiodFFAVHuB6jsP6SWJFFqAMK5V56qXtX8FBdgszAzPTspasiVcT
791	B62qne6iiLkr6kCJxrmPkM9FL3BoWzo4Q4ojmPAQTCPfzKCkQ5w6iP6
792	B62qnT12nXfoEiupbqQY3jRgjm5c5ss1QLLwxhHUy82tTVjofqUNDN5
793	B62qpzWsX5GPqtKwr4FUGprtcQhsSnZDTQvBswhCfK8A1YQkFB8dFwg
794	B62qmmVpWiTAeCU2LNHotLGjRehfujKfgSDxjgb5xfdpGzcNUcdYry7
795	B62qjhFp97dHayikjR9DiBKcoXorthYwU55v3BpSB7SLTGd4wrVfx2m
796	B62qkN4gn3hMKL8f7kY2kvL1DkzpTBV9kaFkkpiZD3rdMYER3LhiWVR
797	B62qoYDE2yrQoVJ2kf2N9Nx2D21Q74APsKd6DbAQKekCFEUq73ioHw2
798	B62qnrkfmfeoB1wXjfcTFmF4gkvi9BJRnzcQnsniMc93RVAAiU1HfAD
799	B62qqWTHw1LzB52Z52Xu9TZmLgctX2jWWuvKsSuaPhjmgAmDsjNpGdh
800	B62qphYQ4tY5F8WVnfzXW4wQmE3o2ucRBBtSDW1mp5AZkdUceo49zkt
801	B62qobj3DXHb3w2D9eZAMj8b2axbeRbJn2Xnrddv7AbSky4DJXDVewD
802	B62qnoWdBv77cHsd5ZAuNyAXc7yh8sXQtHynacN5NZNw2zhq3afBQbH
803	B62qnQEfUUDVxUEwPRM99J13n8TNAszcMHpxgSNm9zjfHJgWjgyZ4gb
804	B62qmxTSCY41R7mQT7H9s8SJZpvLrFHLDpAoSwuP8ghWsH1Kg4U98Ej
805	B62qnYZP1LaZ2pXHCRgbU6vUjMH1s2b8pjNfrof11o7xBLL5M2xHnZT
806	B62qrq96Nr4fsJHKr8Xp3jo64JfqrDgD57YmrsPzCb6WWx2K4KjGgRn
807	B62qiUsYoPyakMZx3yPJisMgz1DpbsW34u7XbYrhw2dQ64rjp3CH5hH
808	B62qiodvWNzk3h4hbXkPgWTkJ4KBqFo4VBBKh6fNjk6eeHWsSURBSvu
809	B62qmPQpB7QLG1ozmbPkHY9AfD64Bg1JEes4T7i8WXtXnAVnKgrJNBZ
810	B62qnxnXm4rHZNd3SaPW7AN2m6JWpDqW7pxh7BorXsuq3UL3GFbNesE
811	B62qimDqNEaG5VGaekbm2sa38ig6C3XdRmYAnJMeCPaopuv6WuVPBkG
812	B62qnMo1XRuLgEdTkBmVwP8xG8DuyUDud3RyPeoBoFEgopEHQ5tKrk8
813	B62qrL6wp7iLQ4UzneLFdGas3pNoSXksNJHDUEanWCxfBD2fi6xXWez
814	B62qpgbBf2GU6cz2uzgBzYxt3AjRYTrLDmsu4MyN46i66whUv49LfCD
815	B62qrZCAKA2YwZ3Na6Cv9VdjF92y2G4oCud1JQtWwDoyvfkjZ6PCtTV
816	B62qoY2cuwsNXaBE3yUwSqwEaovhwRqmGWjBhNL2AH5vCeeRgVsaxCG
817	B62qnDczgqibMNMnATpdsv6wXWtF63AdNz2bMncXwxo7i4QcMMhwwL5
818	B62qoUVGV5aZZsyaKyzA6wRejAJbXaRHCxLzPK5B6s8M9Yp9VAB2p24
819	B62qmk8Mi1gykq1A6EXDKWJCe9Q6AGexJhkVq9f5k1yDLxC5Tsb9B8z
820	B62qiimDyKH2c9aMwzb8pnepGj2ySQMGLctdVtLVLd3KC9z4DU8a14T
821	B62qoVwywhEnMWAKegSqMgP8pmdPeF35UARyuSnq1M6CadpcTAs3dbb
822	B62qjFfENgQq2nRqBy5Maok6DAL4J499x3FUn2uJAVn1ngy2pCAj5sz
823	B62qjfxJWzG3iQtzBX3SGYA4YKPKduJdFDwcJFHCQL4JmWsBNbXeELc
824	B62qpmwejvd6PkaFsUmvGN4KwL6vGKMdFHLqNc8ftQTdfnuKD7QqM27
825	B62qjpLh6MJqKkrJxtfVuqcZ6nkPG7oKRaqLcuwLEf9k2SSgtHgcYh2
826	B62qkXRYVPK4uCnLrx6dgo6jSpGTf5F2z1VrXqDvSK1kksEkkZCrFRc
827	B62qnaF9jEEe8pxpwkaU8ij7SjXbm89PQJxKd4zFu8WEutrihCtbU56
828	B62qkehW659cVAECgC4xFWkbAvoApuGfKddua9ZVrNPs727WmG1wLah
829	B62qpw1rpGnDK5N56eG2uxxdM64dqqoWrq7rCgn4JXPNi2k1P5YycAt
830	B62qks1zLMdgBEaVegEfejneFv7apcQ8iVPvQamtVS97ChZaaWzAiKa
831	B62qp5DTw3dw8ipgSCCDBGextDBAo6FBDSWVwMo1xLRJrH9L6UMt9d3
832	B62qneKBE4uvxZ9LN1Av8Mn674J4yemHcob6pPHLCoHwUvrTKGt47Zv
833	B62qjeTDYdaohKH2Ztb8Wiw59HSiTxzMiiseF347BroJaMnUAfpgVUd
834	B62qjeV5Kj59aJM4qCQ8ZoUmoMH5ANqtgdmZXY6FhXdNwUn3y4NnvNC
835	B62qmYYSw1qctf682uNtc5M58Kc8RoXk7V8P6h938gi7k5pbWPmeVtD
836	B62qrzeAiJZQ4DnFaiDypcprKpXgV4vac8PrmP4rotUHRz5U4JbTy1E
837	B62qkKUkxK1Rayys8oTGC4agJKnpZygNK3WKauCJcyzRThdZqEfcrwi
838	B62qrA9qWwACb4LRFEBQsjXnBZPw11D465L4AByNoDunzhCDntgJ9Lr
839	B62qii9M7moTAxxcG26MfdCuhWajNiKFLf3t5cqvy6eWuEAX8HexWiD
840	B62qj4gpC5Pbh6nUDBg7Xi7DbfDBLd4wQaHT1dodjdEK4pLBi498FZ6
841	B62qp3M2wZGawSgdqY4ysiRDnSEVqfrHVZcBucPMaS7EHEPoVeEBXYF
842	B62qqKV2KTVR8Sic9Yq9P7Z1sb819smRBaCqWi7UuzHgiagLrSRmi6P
843	B62qkUgRDxfBF9hMhPk92haUbMkUuiW1mVC9VbTEF9mJupp6uyQ9RDK
844	B62qkpKnTJ1uAR6ZQ7Z7DW9UwjDuzSZJkTPDDKUGHgBdi5bQAUJ1gG2
845	B62qjQ8dr7xNdox4e5xTGK3rVeSSBDSUfwQYCihRePqfRXfUfDurckV
846	B62qqrJBL4dJcHBRCxXRkCbYfBXqhRHRPS6dnPtbumAeKhMmWzQ3c4b
847	B62qjprTZdUaTRW9g2RMLs5LQ37BiHmb6hoh9kFAwq4jp9mrg4fLJvK
848	B62qrN3hZPxTuAhZzuB534ejuF48KtmfXWFqMLa31NTVcuAcui6oTDw
849	B62qjeR4SzLtURfPd9XoYQ6p389iWCZxwBqMasyLgwRJB2oWwWtnski
850	B62qrYufgatwTD8UkM1tLnW5tfnSeWYSPtbBYyYvdQ4dvoA9KBeWfcH
851	B62qmzFTUsRqK6UAQuu1aWdkyhaM29WrCdGoo3wUm8W1A1ahCU5iBsY
852	B62qq4qohsvmTAJmvJ5wSepyNHKsh1wMPf1UjoHLKEuLmgH2RdAa4zt
853	B62qpSarkCiM2BtkyxEYgHXVPVtdghrDRoTKjXVEdVMrHmpe4Yqc3xS
854	B62qoA478cjzLTGH3JqDrNXGjQNGQJeKesjnS6o9aVv875epCMtrrsD
855	B62qj2JEHwhtaq45YYudYUEkcF34xdukLYaHreXginU3ddL9haLC15A
856	B62qpk2BRXnuxofXRU1z2y1LWRagabiSLoBuCJjDSv9ebVkzZE2zXnp
857	B62qqyxmcGrRFNDhE2rAQFeYjse5SNJBvxjkJDqu7gZby56w8gyioB7
858	B62qqhTWoZineudzfT9o4YTdruHTps1yANJz9z1Zw3YnFAMgCky8LFS
859	B62qpsMxKCoRQnr75yfsbHAsGn2Cn9YcHYRvXhgzURkGdYTnj3xufsX
860	B62qpKUqR97dtt9n7CSrz1yPjfBHg2h7yksQ1gRiyB9oABZcXfurTzH
861	B62qq1p5NS9N8D2jGKQDZkd7UrADvK3EeysJMRnT7aXUi9iWEwupNiT
862	B62qmCwouxG2UzH6zEYGFWFFzUuSv9sbLnr96VJWDX3paSSucX7jAJN
863	B62qpoHJA7xwPegQPSQ4xa5vQEd15uhat5r5XRrrm9wUhMPbdF5CC4b
864	B62qn42hMGBuo5UGtLMDvfZ5eBLnkKVHTXwnQkktfujrLVtco34WFqx
865	B62qnbCsiNKmdj7GYaMv3Zf6jTDhpNbMTAQYBZddCctnrxrkG76qNeH
866	B62qrPH1SqnVrh92QART2N8sjmjRqnidtp4my5SAxstpurqQheNAR9u
867	B62qqoZx2obVArX2Azh2D6AduLDv3BpPMzJaBTKNyA8RpQ8xjJYcH7E
868	B62qmtcbMEVVKN2guoyVEqmiPZtbvNhz4VUvUYvxesya3WHPkLiBvdK
869	B62qjdxMGGRmQ8W7tqRaEuVFQgSPqkiYqFDUKPkJ3Ks9d23Mwmzgphx
870	B62qppJosj13spPS9ZvkhqUfqkTRH9LHYHcUZR3Wivayjrs1tZcZxXq
871	B62qr6JLYwR73PNJYVyRgsPACXduQtebRGUPshKjeJB26pHmF3tJWr6
872	B62qpzxtQkkNdCARWbcFhrQnB2cc6ybjDHhFK4zuBm63QgMadjnUTSM
873	B62qr2cpHeCn7XtQA5ktqKMQ8gmi6UT79SoGatfvinNyBih13tr2SuF
874	B62qrQW1u4635tmjLjkz7pdUrwE9QhmYP8rPb13SpaNBeHa4pGidstk
875	B62qkpgRQcmwDPEt25g7CoBSE9wY8HWCzVsmeTbvgZ1757rKAtUAPWc
876	B62qm3hoUHCPWGdKfrSK5Ek9STvGfwjf6L1uewvgFQHCVY4Y48DT4Qr
877	B62qpLv2AVt8zikusA8jkHinfWgCtLnfnZKfxrzitDBoqozwo5pSSjH
878	B62qiX7wCtUbpzgJavPKbfBcLJ6nyYB88cWjfwjWZiyZZLS7weCDxwm
879	B62qouqyiJfmysbVqgXZJy7rDvh2ZT1w5vmEQXqKAkpfvk37xQePyYL
880	B62qiigQwvLyyqUsAL3SmtjP43iGnUB1s1mUYrhvyZCc8PVFaW9ZQvd
881	B62qoQg5s8EsT3wL1zNT3sjbsJkGXUnBSfukzB9z1MnNUo2DQD24vus
882	B62qnbZcyj5U8N4nqGyt8gf67qsGitf3LFfjRsNZuXV6c3XA84V7p1v
883	B62qrAFo1P6wZoE43hPKcRWodZrC7wZFUFGHYwFgh8zyrTyos9ijLSf
884	B62qizxV2Z1Lbf8TFb4Jzf3uJTd8CDBSuJ5ypkJdw9pZNKzW1Rzxrwh
885	B62qqNrAYrDKKMve6ECt3mgBBj8g9M6xKR4gdNusetisrAhUTgpHiV2
886	B62qjUNbZhrc4vYKfib3kfL8HRAg7ozdis2MhTXA9tobeEbwebdBfR3
887	B62qie31VMdCUN9VbJMP2D9EwzcdcF6iYjBzYeTXPiuZzbLaBnYkJ54
888	B62qmru4aEDszwLFvH59BtZnU4QLC52nrSRBJW1EfdAp8cD5drg8QFM
889	B62qjpDZTY6ZXsGSJpMvZycBJqv6VFQTStdrEARwh53qPBfcBVuMSRm
890	B62qpz34iGX2eaRDyHmHbq3v1SnUgzounhudGZRfNUDh79JuTstPNy1
891	B62qkavJuPZs1bqRTdzmACy3Qf1o8FYRbh43qRPvkB6tQconwjFuAdx
892	B62qjUut7tByYkosrfLDC5aKLSLQ2JxTbkBcfF3em3HwiyNkEsQmwfM
893	B62qoFS9tDcqaxcatXcr8jdTECpTXwa1vMNfuDkEdp4tc7uwn1z5ELx
894	B62qoUiAHZZ9xY7BibT84iwMtgQidQByE7tCuNhn6DmyKhUPAzpnJAd
895	B62qrQMPSJpee1NnxVb4cr1qBtH3kMNpXaHVj4oVxNhqadCMBk6wELy
896	B62qpMJkbt6b6n97jhW9iWfvmseaqaiUT2KViBUKUHtE2MbxVGSPBnc
897	B62qp78FJiBUMordLumiKQMewazCwcH1Zee2GuK5MRrEsqQ2NdGHsWE
898	B62qkK29ScnXfTzrDkkfASepKoTE57CT8SA4r43EQCCwwJXAsP5TGGN
899	B62qj1ddvraTFJVjVVTpDCa8Cs7TVhZGjqEomQrpahrJ3hdag54cGb6
900	B62qmEo9HSSLLM3DtUJwcNdeqqQ6zoNUMqXauu9ySWKdpo8W7T9bjR3
901	B62qm4km9z5EFAGe2ByVR97gvnbbx57FQu7VQWEviPQHtaSeApBKjQB
902	B62qnipPgHt7ajPdMko2STLDAxWW1M5q6sZ8V578khR2KMQUbhxtTPN
903	B62qnhoXZG3BqKWJ6vTmRFM192LqvKZYDt1UJP88gi729USiio87AtK
904	B62qibGLxx3ECjWgU2YSJ2LZxXkPriLyPHZEb6FCdMNMPzAphSFZnWo
905	B62qrGcX71YGYbgik6onTADgDSkk4huovAhjzJRZMdUZLJRVZ4wG8dp
906	B62qknoGUuTS2MmtZMrJLX6SumUP5BjKJVhyPTKjSBH5xyenxZ8dTWV
907	B62qmQVRztGMtwamypY858BbGPRNmoJTrqMrq6xb2BtGso81bEzn8bR
908	B62qjWrka3sHmyX9E3LLk7DYwTkD3xpVxJVWeC1jWesvUCw98jzwLEb
909	B62qr11GnajdtFtYHLB25VfR2HisWw9gQTtswLT9UDuBDupwxnP8Qtm
910	B62qog6J6WmV7EG35JYwCoMjXGQKfMzDf882feobdM4XSTvd4TM7o4x
911	B62qmQAFPta1Q3c7wXHxXRKnE3uWyBYZCLb8frdHEgavi3BbBVkpeC1
912	B62qkLCr6WNbmpwmV3zLUM99J46WGpEJLcBbQEbQen2oXV9MKU8f9mL
913	B62qo41tpoLx87ag5BcocFD8QV5jQB18qw8jnNqKGz9KDXna7PT3DLi
914	B62qjFozcCaaeMNaAWrRT21JUsSaq47PYW8DZdySviwath3Mg8nyfCw
915	B62qk8QpsgrR4d5NM9gxiiN2oiZSNznfeDbr1V5pFWa82nZy6iwKhfw
916	B62qnJ58vM1du7EkL83EPtjN8wt1MXKC93Sbe6icpRhfLVgDg6xnVgA
917	B62qoERQaxigi8r2cjyUuQXicjcPbGZfjRkeUn5sedzYisjTBNtEddh
918	B62qpBVRzjqFcbzMk3JAFdjruMAoqdHyHiE9XNyshZ5NjGo2gY7CxZz
919	B62qrr1TdC3LeN5F1Bgjxb1v4Pdxt6btzKL7sGTyLGNcydmagjsYsQi
920	B62qmanR1vreSJgKYZcHSiNrov8jvXShfcjioaBLpCGbr7vrt3DxZq9
921	B62qjCoLPn8iXHXq9ukNMhAfqn39o1MZKsAx3VrWFdu1pEbZZezJhJe
922	B62qkZvsPhMjgYTiXLLGXWaFUCFGAexpR3v2z5ymXKEuZGVhub5ebNk
923	B62qodbQJ5bnuY7j71eaYiiiq3XqYDgsBDJxkAhtzqBNpxAgskKdTc4
924	B62qm4UyivsseKABrgJxS4AnoK4SX8b69o4DWrR9cJ8HRYGrNq65iEG
925	B62qpcJd5eVzs6z4hs47nMQipXJdz3nEaEqbLStc8obzecfNPv5vAnV
926	B62qo8FPFHTQ2J5eaCK74yfsMRBFT5bnr2iPomWLv61iGpaufBop6Si
927	B62qpGX4AkMb93fusVyC7CDNju7FUP1fFVbspw8o4sN8xbmsiKxgy7f
928	B62qqLBQFF3oRGthJGnbZB9PEF8pvoxGcfBNUVtgXtH88VZE9KBoGKb
929	B62qnQ9R4djFcZtgUnEASzipJj4Liwdpt5WjM8qnQvWH9QZZMwPHRJc
930	B62qjyUJF51Rh87LkCzFUrWFBC2oSqL55dw1bHMkPov6oGpqiZxd2Xc
931	B62qq6YfopW3J9zaw9VEjQP8tehZVzewtH8LDrPST9FtLWnnWhnoKJ6
932	B62qojvcsxDKjfx2UKTfrsrQ4XYt3x9gpUfijNtTyNHjMyKigubEL1Y
933	B62qnem3qr442rQCJ1cmj8kLqk48Hpi1PEJwPXrMUNyiSymQQxSJspn
934	B62qo8yt9f1eQAv1kNUocT7jWKcHBTEcMxkSCmK5FSn9eKUfy6mZpQc
935	B62qmXBgmuA4Zo81V5Xmhmr5opdAbbddfyVxsdvJuQutceSHNQe2Scb
936	B62qjYCD9rCC9mqfqdAi929GRuZBmNfba2VomgfRVtZQzPa14YguZd4
937	B62qmSLcBAgGJYa14CUyGdoZywpKuztSKWRJsnKFSxg3oeLAYaotLFv
938	B62qmmvXhqFc4KpY8o78Nx1N2gusT9zC7D4pairouAZHyJmutVqApJ6
939	B62qiWWh6F34fwbZiv5uGKg15vr4C3cxKDBxR4xypdgQErk4t6DBn9k
940	B62qqMhtDSFToxQLzPjZ27PVtSCZR9rgUrjUDcjytWSsDZtPFiQMrnK
941	B62qqUrqjmVerAGWSk1TByCBQxzH8u9PRnKnMu2YH7YbhyS9CzMnYRq
942	B62qmiBiazpFUcs4t2ccJ2vEzh6i4drnyLQfNV3dEfgZfKYYjAbu8tC
943	B62qjYKFSc4DJ1g1PGuyooe8BGXfQEiTUb4oLH1jhntZtQpz9aV7WY3
944	B62qp8no6FregychSQusyD56DkRrqvg9bhBF3R3BQckQzQoUY9piJ74
945	B62qnWqVhYZaSn9xHkpih2rkbZ45MV5Q3CktwGA9EVbZtrGGjSr83oj
946	B62qkeKupTi7525nWMQfWgJ7EhrxhyFdnhANKrjSo6LRCZJ28yHw1yv
947	B62qnNmzW5uoLMPEVhwfL5xW1jCALVRfP6CEm4wPbyuu5xxJEoxBbue
948	B62qkDGi9CVj8Gu7wA3Tm6R1eUa8ZxZSUeFoQUmAjqE1diaXYcN769S
949	B62qmij2xZg5ZLmMUy3Be1Av54misfGR16ywRJAsPhMvdUWpzhKfxD8
950	B62qrYfgf3JNvWRCrWWH7T64ForhkYTSRbu5QM51EFxD1Q6wF1wzFNU
951	B62qpKeaQG8uJxYGdMWkhfff75YrFwoxPwSzhxrWxUf7STrpQMMVrYB
952	B62qnBRYDxf1EG23jnJx1QAMvARTZgdJzYoAE5LoEUJbLiPsUzYfA98
953	B62qqkKscGbufYJ5qpk3GLWenaJCgK5TgiaRwozsH5BmdqXGbttGYSP
954	B62qrgWoTX6rBSPFyo8ffBuQzkkVN1yWi4LD4a1u2EH3bXJY1bTd3Vy
955	B62qoHY9jb2WaBK1t4HgboN7vCq71X1aBGfdaiQdryuyDSfsgCDtd5A
956	B62qrxjaEqDqq1VQXc9xPXU4DiJM4nBMYesWs7whmNyFrPr6Qo4GRzu
957	B62qmFMzdoZMdhvU8Rgvnk6cLieaAMYQbjNumWj9cCMuNVLmDXKta5d
958	B62qkCuaxdGJGKjPvYa6TEFqmBGc7p1CmLwAsYJuVA7iu3VTVZQDR4b
959	B62qkQJjJt3PL89vVXoHir7cCFPgpdJ1JCmhqHrfwjY7zpGYhtC2xHH
960	B62qmnPjiwSKnff1qMUuYcuixn12j251x5fKKaxPtWDajf8KgaQX6yU
961	B62qs1inqycyihVap9Ti1T4WrmqoZ2aqZ49z4peRYM1cC8Gk3brdHk7
962	B62qpJZYLwCjH5Hafi9YiCGGgVhuoq9j6A47MxJG3qzH3nzS3pZZcnn
963	B62qnKSBegBU5wkkYQfKEKPenEsEttY4EVSuizJNrZdsdrkk6xSmb3E
964	B62qoTdpaj649XnqLxGq8oY6j3pBQdujD7ftQpq58AqypTMcaZePfUL
965	B62qrxrrtdZGk1icXvsEes5DBxHuaoifF2MmutXzFPLjsuSPouUbcEu
966	B62qjyY3c1FNPLUir8MBoECUNAP3CiDFE52uc4LP8B5miWe441e1VPo
967	B62qqJXC6J5UXVNW321LiGtwFR2WTGULFwZzrDo874BYi7QGdrkpqFY
968	B62qmQQ84vg6V7NwizyZzsWk4z6P6GdXrpvN44h19TRL9dsa9xZ542H
969	B62qmPfMY7HNmuvGnQQ5kF1UoPy2ipNXAF4MtmZvLipAynggd6EWWBC
970	B62qpqgV3MoZEtfPiceJ7tH9ngz9o7a3EtkdFr2a9KnRkQGaxEuW4iU
971	B62qnysDggsacPKduRXXMzCgbU6ggCSGUywBhhrGX1c8W4nr5oSX1Jr
972	B62qpYG5JSiR88NHKPbceqDDs8MTnhmvzoDWbqbJUWEXGnuVjooaUPL
973	B62qrMCR9BPCLY2ZWMXH7ueNJM6ZCa7X5cW2NboAfpXqaiDadbSEoim
974	B62qn3jFiBMx57Tqw1EbfHPtVqaEntjZR1uihQ4jH7iQLBFS3hSPKC5
975	B62qnzTCuHo79TU9chKbcGLudHS3fU3NhLReJG34MhUVrFN6nA7Pjik
976	B62qrNpfSTjKyBiq9LEU8wNSHPu2YNPiv7sgS2yYhACKjeXWUmLvAJ2
977	B62qnFpSPGZveVRzoABYjsW6dwAXjcGeAnA6CsBjAsG86ZthTGwy7TF
978	B62qitq9vwHhBXHwU8Hu9VqPGniVUs7C74RbYz8v8EtDTnBkcLC5t83
979	B62qq4x5H4WyTJHywAZ3DzPCeUcSz1Gh7TqMP4ydANeETB68Mrf9X8i
980	B62qifDaXL1vTRa88w3w1ZcUUtK8QT5nUF5CEAKNFrftEQMu6afkoDM
981	B62qrTGV9jGcZsxDbahBPPheUd5MpV97yzAn1QrYyEAtzgfbURC3dMa
982	B62qmh665K7crtbKv7JfNQgJcBKh2bZN5vw3mz3ds6vVo76M2K7byvy
983	B62qjUVRD9YVQ8Mt5fmtjCt4aUzeZLDMSop8yg6Scg5unqDXiyM2SMs
984	B62qoTaYnDYrtmver4jnkgJbFU6iohjtALTU4ebf4yCKrxFFHd9Dimh
985	B62qoreEwCN4QMSJBcrEgDLzmygNKgMkshRxKGMZfswK9oNpoZC97ZS
986	B62qjRNvNj7EJCWSRfhKNosEYnjTCZVbMdiyymV2QxiYpr8QQehgYB6
987	B62qnsoomKzFNvmJcWAq59TLtidzYwD2hcUCrrFhBNWys2npQTXpGmu
988	B62qrh8V1qvJhQx9D6g3JDgVg1FYR8B45V7EFFim7aLPLss3kD2aAXR
989	B62qogpwsY84waaousZTWkonka6EoajHey2S3cfi9qzSbynbmGiqaUN
990	B62qiaQboSdk5JkHTNcPWUjDwVZZK96u5tGac6aLA9yCqVm8tZLsZZm
991	B62qquq5R18f5sQ1LPF1MGqwwxy1jRCeMEUsMuvjgJ4dAajdQgjcye5
992	B62qrzN4SfQpxV12YcSW4Crb6PY21y4sgpq7e3v2qh7x5UEd47RpNze
993	B62qnto268cEnV1cdZh2bRS3bMwiAT3tRxsPrfiYruHaxXERAR3Ec8b
994	B62qku85TZbbwZhuYr3xMsUJ7KndwA1wHcCDVvawK24uUtBjQDa9pye
995	B62qm6aynoQs9WmAbkoKvSn3eMDo1PAZi4jfB2MnbUWTHsq9TVKYZVJ
996	B62qri8EQAMZbZiwaYXtuh3fs14MRPJ7x3ePQh25SmR7ggKRtnfJ2e2
997	B62qmq4EksfssuNcoAvFhebPiBry1uUR1bwLEiN84EByVPAcVh2Lvib
998	B62qrFQnjeR8FesCFUJgNmJkfe6uzYMGSverRyDVjfQxDPgkr8mzjSq
999	B62qjtHX7MLXn7cNM3cF7Eb4b7cgwrk6STeUjCtPktusxFQ75T3BMPn
1000	B62qjaKD4AAxb8UUQypqysaFx3cYhp5bSjzgkQobyjca3sRJKho3VA4
1001	B62qpDH4cXswwo4YYmdS9apCeRQUXtAEXuCS95ddMCFhNbzxvzZ6Nfx
1002	B62qpJ4Q5J4LoBXgQBfq6gbXTyevFPhwMNYZEBdTSixmFq4UrdNadSN
1003	B62qnNyeNzkyccsgwogTg9jgqBYfE6KnjTWi9QxsVkQ2NKgW2i5fDj9
1004	B62qnsA7W5yWUr8r27DwmBoyHqYE5FMpm5NxhotqppmbL5wxcBDZZVT
1005	B62qn9zWo5HcC2RRRi5P8278Hq5RoKgQWqFvXRYxsbVQeDCsAJP7aop
1006	B62qqsZBMoFs1AmiLxekCDUta2GPHPyZenug2DM4jrVrrZqUHi5PEsY
1007	B62qqhHF6ZZQEQ2dNyjSSMy1uSqy8JjVnoRmN4k2q9VPfAEviRpvype
1008	B62qqSy5saxH3Ago7obP4XT2M9fYkRLMfthRhgCw59jr7EvHitk4VpK
1009	B62qkVtsvZk4sMHJETFDeqzukb9vEbswirZFY4afdKYMqcAEw1bkGej
1010	B62qmBXLrMyUZ7HSTcnSpUG2DFcVTGtVFNR5sSkMzshTjJyk9nrJRTD
1011	B62qiscckHMmaedeqpSokpjidB4WQW74tmWAzXWG8rW3DgTfEfXJazj
1012	B62qmsgdnJagaswVUo1KhnQNGVF1y2wS33RcR4kS85FkAsJ8xTdNuit
1013	B62qpGm7Ubs2exzhPZuHFCmsCRrhBKigUUoY3p4gSBq2koqfYRFNbjX
1014	B62qmm7feizW8hGKBBzvh5gpdDbqhMac3zLh1hVcTaj3BbYC18Eivi4
1015	B62qkwYTYFzemJK9ozx2K2fy4YsvFx4w29PTBdwP3khDfax8tUP8rJo
1016	B62qm4egneDvLXYCwzJRLBQoseGZezZ4LUtJUT256phFLm9TQWGmFYb
1017	B62qo6bK6jBAa6QR4EYYtH6MWeGRfWUWEWXPjbYsci15ecXTafkSw6G
1018	B62qqrMW5HUkhKDPuNLToVyxcc49VEPRMaRFzSbWZysAsyPw8nFAu4T
1019	B62qkTViAbMfWGRFJyvtWT5dBrfBUReHTHsA8PWT1dBLB4ctPHRf7nw
1020	B62qqsvgiixjji3CX7whzuBKVupvwgBS4Dao6wDwkmWPi79TNcwZ1tB
1021	B62qmtxhr1gQ5PUvKnNRVfhuuVs2Wjn4xPBoXMWujaYi5D77gShXH6Y
1022	B62qm4TntJySX6ktHD1SsYumBdvSTp8pLdjMwTVjBrmA3ipkWejBdbe
1023	B62qo1mUFu2xFntFTqPhiff3TEVyhu9ukTKvp81vqzvBUDs76DYTGuo
1024	B62qnfJ6Yqn8FKmFK5YfiskzD1axjxSJwP2jRtNrDUiH9tN59xz2KgH
1025	B62qjVi5acmgHpTe2h7Kqw69xRXtc8KvJANmAnx2tEVUz7pSpfrLFXr
1026	B62qq5MpA1CzLTwC45zADGS7rRGZoQ3kmnf1nrYQzcnETfoJvU5vamo
1027	B62qpJtPWEqXnDcXLugqf3C1m4ftWf2DaXLK8J35Ka7HoZSCxKBDWbP
1028	B62qjbRyvwkiMNwAvamp9wfFoUyhwGsQZ2Np2j1i68HdbYLqviS7hfw
1029	B62qjAbb8hxvgGfpJLULvEA3A5yPXmZu8h7VkEMX8wAwpGWEcAEQLvz
1030	B62qjeQmtThR9HKw3z5oq58RHfCtdvyJb9chiA2R4NReipEu4nrbPHw
1031	B62qn71s63yywMUCcFhP4iCata7HpgyrvmGjpKa1D9544vGW6FBZ6a1
1032	B62qoRkPZeEekdcQWRYCrCTwcYicVyYRCiU22gggFYUTatWBNHt1Jk7
1033	B62qkaYsXdwZ14UoLMtrXAp2Up59uUFZyY4KpD7YbvXaMo3ByceyxD4
1034	B62qid58wzxcQARBwdYmAYc3dVLFirx5SRGLdHUqMkQb6hVsRpUzgiu
1035	B62qoGbqv395zDfi5Q9yPTxLgvfcLtFwJdmJ7nJ3tLKU2M7CjRY8kCa
1036	B62qne8eYsgx4dFc1pBe4efuwamHUuKz7p1Jywyyk5v854eowD2dEMY
1037	B62qjdPSYuVpB4uLp9V4Pw36GP4CgqKWeJExjzHAipL8KbrSa16uvNw
1038	B62qipFGtaHAJpvGSJdYdVxJw6Fg4SdRK6Ldu51o2rVUGJF4JzgMqna
1039	B62qo145pgATYorapx2boXn7AbhhwMTnWK27phLBkYwQJjjpCYXxNUP
1040	B62qnAwsnwgn8okBLuEr63egNYFyJqZAhWwpyccbTZfyxMJgyDGcVGx
1041	B62qniwr9y7XYbjy26rgu3UCFwHBzsnQocu5gnd6agwbZU7Gxtu7WJS
1042	B62qiZppGFZmWNLcGDrPp4wBBcEKCRhSzY7VC6U8XL97ybesV3GECLt
1043	B62qmQ68xVWawcdC3WAXCDiw7JevnocVfzdV5pq3gBiia5RydquLUcp
1044	B62qkxHjXkxWcdnep9neiFpa84Dywf5B9cUNrmrMEJ2hMmw6iUeFieD
1045	B62qrJHuDFWfuWStjyboPejGaP4HZqFRPQxsQtWaxhnV4iJBgfcH1cb
1046	B62qkBoe9qNqxTiXBe5euvRvZi8rCUq9TgHfM2BwmcED7ADJHFkDQJN
1047	B62qrdVeRr5u9kBomM18PQdGh89oTthxgsy8JTjSCFtyzGD8RWwUjme
1048	B62qjpzAChiHvZZqchLWcv9SAc52p23oCerTPPrZzFqksLTgwSBo8Ax
1049	B62qrxhjraNf6uXqLgWBFVAhsZqXAfpXAPm1ASZptnEhLZctRTzykzM
1050	B62qmuzvR64h6vEt87ijpikVsVeoYdnYGwM5NFSQY98j3CSKw2i8GiE
1051	B62qnpc2JJrKj5gash86vodGFsLVQawaLSiJwbUtPgLs8dcp7QyBzYr
1052	B62qmXrQB8jpxHZ2i576MsMCiLNorggtfz9b9zVSwSSo6bdaimLMVpK
1053	B62qqARg6wBwTwt1TQHkDuLqHHyYzPK9APb7vhEdxsUmCKaD7cQLHbp
1054	B62qpYVQWpALzvtXLhBLcftFbSLv2bhDJYwfctSG1DKjE4by2h3Z9Fo
1055	B62qnXfMmiMFkkpyiLejZgMuYYJuptdu2tyXKun1VPCS2xhFrwqvy2p
1056	B62qq4MsguV8i5recmWUuYFWXpPW1MWZBjjjwEuChaFRuTioP8VUctQ
1057	B62qmwgXnydnYAxhFLbyZ68zDQsF2yxDR92UUucBJY2i2Mr3U4Qw2KG
1058	B62qo92C9siz8nua4H3mopoLxbDVV6dsoavd4AoimHAqA3ojM9pfh37
1059	B62qrmk3L8KdNb96SqvohxCKZuhRVGRYYTMAgrKFhAD5T9terBwG63K
1060	B62qin1sCKU7TQbkZ6Z5ka2armpaxkJgrWSWgUmGWG2qWBTPyxtqtuL
1061	B62qp3Pd3QM7HXMYMdhWTjwTYbWZVZe5s3vKxdDvTV2YPSn4GBQ3M7E
1062	B62qr7ncXwHeBXyQP2dThpWNwySjkUDCNagFkRba5jn4LyB5cSUioXK
1063	B62qovenu34m8jqnnvxq13NTmpBHQbTodMAAErSXNzshZiTQZcCtjNs
1064	B62qiUXLM7UrRFZxSKg3pLGRZWnQzyhLa1jvbCrhWUtfDpUCwEdyJz6
1065	B62qkBU1d1gVffSCVvg1hsgFLwfG8WAkfrCQwoNbfLosBQMz7LFxF2E
1066	B62qkPod2ScW1RBFtwUJxA69eNDfE1qKRsj8wc9Q91WQZdoTHorfTfm
1067	B62qnRCUTA8azwS5yrsduiwY6q9M72ghdWeYR1G7hvmmoJk81XPiU7Z
1068	B62qmLLeHwVNq3ZYM7ETt6n53s1YHRv69WHzJ1NBMDGkCVcHbUThqFe
1069	B62qpurNfxgxGDDfhaX4VR8MTU8tEBwRtgWFYUiM7xiLm4Nqu4vHKbq
1070	B62qkTfWwHvCvcEEr8i7zNgUT7FivBjWmE5wQu7yzeQxm1AvPr63g2z
1071	B62qpNyjUGZyRXNpRKmVyPezie8AbVaTVfjHbFbUBYHYfQTynfd2mzq
1072	B62qnQAEgB5zxKCz3icKgpjJ5BZwsTRE51gED6sJgRzzuSxhkdKSMeN
1073	B62qp5Tbn8gW2FKSQkrqhVtGxhhrN5KQsCYC4rdASHjgUxn5vVezMCP
1074	B62qjkpzsDcW4w4V3SS9LFuzFiqpydVvJoJYixgAG8qpMDPpaRnTpHE
1075	B62qkhoEckV1fEZUJwD7ghe22ZGucu1v7jjMxqhCA2AwtTAQHLSFqVz
1076	B62qmDwvqT9xNNwee5gZovcj5E8Vox2STA23x7SYRsiC1g7dKo6UJvx
1077	B62qmg9tWG7RYemfvWtXjAVquUNGuJ2jgM1TkFokD92rB6yLSwLBDJD
1078	B62qqkvZbFoWwAhZiAJmrHGQWY7q6HAnhPhLMs9jeZkDKFRqGgXHrQc
1079	B62qmvq7k39ZHC3t9yBKXs3rkYBPAKXCWpvewjLJ64prmVqJWwDWKef
1080	B62qmfGmXEqtyxmQQUjZS4WGdc7gbB3aNsuo39g5S6mY6VVr3jwnz29
1081	B62qkoHmyjLDFzm8zcz21QWb3g5uagqUZBpssygbitYUMpd9S5sd66B
1082	B62qnBCL2nL6u38wLVqPWQ6VagvCBcaMAXRiBY237h1NJpubThKs4Tk
1083	B62qoWGif7FBbK8igStzUCukF5WMJZCqmFgdsKqHQSBsLdB8vWZrewf
1084	B62qp9ZP47Wxi4v6GCHqVpbAz5PeQ3kYhB3WXy4AJvGZ95gEeveUPw3
1085	B62qjeBcbRunMkcTmKTQ92nrMZUmoFKMccLBTUvnD43TL7e7Z2PMARR
1086	B62qnVUKhkfS6aXNaynq9X1xLgdBBF6RHET4byPsqWEenj1dK1P2LUg
1087	B62qigJASqWfLEfeWU7UPfSakDYrdyAgWHUuyX4kh2nsgLgBeRxpn1P
1088	B62qpH3jQdvyx6BWJTPUgZHf8WXFhEoJRSmAqTNh5XNtBRH1fjkf1gN
1089	B62qk5fAkq5XDDVGTcB741M2pJ9Wnq7srbmCadRWSkC9ne3Nubpgf5t
1090	B62qmQ8ncnhsQR4RqBMcFiwnUcmuRHC9kYJDZSiuJ13tN5aAVLUQX45
1091	B62qk5eE7w3Jqu6wGgXTcXt6ScVv3hCQ1kZZrWANwnbwttmZfYZLW4Y
1092	B62qnTQLp9uHwzmxKuyDa2UP3QHpPZD5KiVGPegB1ZLWEC1DWC4h6kB
1093	B62qmNZb837DtnkPEKo8Ph2CiA8yGCuG1Hab5Zen1AoEWqUjCVXDiRV
1094	B62qoX49KkvYNJt5VQd9rUAgWJuF9UqpbeVKwitzLDC5XdwnbYdHAi2
1095	B62qqy2yhUCw3NFqA5XjcamuUQYXADNU3FQzKbTthSGW8P4Cpnu49Gf
1096	B62qmxTFPg2u55SEbookmXU8niMu9B5vLrybVW2STdKUb5tj7TtvabW
1097	B62qphNw62QBjfwsoSRxeYb5sVyde16WdxkynC2V3pUR9yuMFoqHDUE
1098	B62qrZ5r827VT3if6vgo6UaHy7sfhRvVyRsqxyswrEZ9AwfiWpjy4Bq
1099	B62qmRapzi3nrctTihmaeH3CNbsDkpAAmf5osj9SvucNTU7jteFchhZ
1100	B62qkvch5mqkErUrN5AQpXS3MicaCdUhScBVjHqDfbsbP5i42okjcL4
1101	B62qkVHBqMkm6zmvBE5UHn4591dfFk8d2JLysx7bvmBUgwQt796878j
1102	B62qpWiEcSPE4cf1F7UaWPt4JJZvme3B13e5S39tKNgqu86pszn5scx
1103	B62qmFuBwy5JUZ9rfRFX9YDxEj9xAP8fszK88nYRwxs1zzfVG6hPXmf
1104	B62qp1MrxFnKMUEgAcWq2AJscVJTVzpSZHVJjgf6GGS2fcJTDU5LhVS
1105	B62qo5aeu9qezh2Z1qsKV47jHwgt8MvYLbKVWUSoi6iNaX165bAtmT9
1106	B62qqxHGzvYKYH3nCK9fdB8Qvc53rF6VTDRDz1sSAnNTJtP2G9G6F4U
1107	B62qpNBeLFvo8dad9LX1hp4aJa833b7C8RUnAP4EbQpQ9KhrY5roxWa
1108	B62qrP66ehjMUjSPV4ci8scX7qrLYguLDEmDhQxsq1TS9BvarupCd71
1109	B62qk64MQFspF9kcsU6QvmhCX6knqYRmUV8LGWKfNQWSf1R8snBPaSk
1110	B62qpsfgietkCzKKfqbjdUmWFPjJRTykEabpx5U5A6jWdESh2eDqBNs
1111	B62qmxDvkGqq9HzcPBWMxykMzNHEHuVyP3gWmNSy2CPT4hNQHzgpbxP
1112	B62qp5A9NfjDjtcqy4Ud4FKd9vEs41Q7WPdSAzu78NFK5o6vbhExkSm
1113	B62qoLLCQiB92VKj3bBpx6hUvat4bYh44cPNYWVPRqf8g67D7QPSRqz
1114	B62qpyJsdHDj9mftCE55BX8JAsXh2MJtrHkPusDoMC8fUcmo5EWLvY1
1115	B62qp9RWhUJt949SZKJNWq4tJpCEgEjFHD9H4JWLpxC6CkCgXQumCA1
1116	B62qr874z9GXC4SiHeiX9cikUa2NUf1ZnL8bvmQ3rdq35s3fRYWwLTc
1117	B62qpPFVqxDmJp27sLQzNB8MnkAcFTwA6QS7C46dMyVYcfq4oUyTY9n
1118	B62qkMBqD63AvYC9gcvJLPcdVbNAG4wwjHsqB5wpLiuzbSjXiL9qHwj
1119	B62qoJWcACRGWgcd7NBwnfY388ghN1dwoF6FXXLJtwsCQtgxUD3JXMJ
1120	B62qqdFzNt7f3h5GQZWmHZhRi85r1F5vbcikoFPB14KxsytuukfZ89g
1121	B62qjusyo8pPwH5Ho81j4CPEKkVLQGeQmcGsn2ZaEJLxJzV1EKsWYrk
1122	B62qraZF2Ep3WheJdmtfQ8DG6JURv8giNdDThFV7eNXL8smFxY2RNiL
1123	B62qraqoNtsxAVCpmVSZF3DVLzmM4uo63dvomBSogDHaGLJRqm7aC1D
1124	B62qqt8AE79NdNDBPSrRb8HzpPqC3hTgWRuRtcbT7nProHH3Gcv6tZa
1125	B62qq2iUH5cE9b7Gjbw8pDvuKpEzmqFiXxsDazHqiN2tw4cKoomvjBy
1126	B62qiaGV9Mtk8ZMGmph7WiYPzuZYp5qvbWj1Re479rvGeA672gmRbME
1127	B62qkkvP9xAwiCsh9SqK2nSEQxf6pFG5kkZ5K9Vr8wVzQR4uhynpSFw
1128	B62qoRg8wZPkeTL3bhMkay6Fj8fo1hJF6iZtanxrwE3LektzfLCtSqd
1129	B62qksjpcicN4YAXFsvojtARRNyDHuSJkYS1tVpspWfxPQg8sdGivnD
1130	B62qrey9e8ZsaaJv2KwHHowBhn2KvTcdjSiedqgD6nMQoh6C1F7K7Zz
1131	B62qk5QuT23z9F958QrRcKZ1ZWiXWmwj36uXDdoNGSiSxw1hNgn9R97
1132	B62qifWG83TzBDNSbqsDkmmYybQx3umZSTNeqQ47t6mQcpJhCHtU4af
1133	B62qkHVcy87zYztXYmRuPZ2asSMqhxkpAHwGfcCToB1R7DLHnPAvqrv
1134	B62qph6BZp2veywEtbtULgepSmDvnXz58mpj34gvBL1iQj5stHpavd8
1135	B62qpJdCFAoycomY7LRfNXZDHvULj6ug8bh1huFVGMGzX5jwjQ7JQ38
1136	B62qrXCnHQrSf3XnAnSb1DCUDka3dZVWB2XqH7Axr2vg2KaFXsX6G5R
1137	B62qrnLPoK3bsQvrCM5mFH5SkkaaGBhYabSKb7zUdvDY2F5nb46HtWS
1138	B62qmHpKBQ2FzUQijFi9UMRU2txrLb1GuQMr7vUCzLqnDJexwTdgKbV
1139	B62qpe15stHjxU2pvRDkM9hp6J1hWD4Cf1zmKGCtzsg9awuVK5GxcUR
1140	B62qpMzq4vHG8RbUpEVuGrYG8tJP4fPEbUwosGLpwLQsBFQ7d5WKdzc
1141	B62qmBKWg1Z8cCQoDGXCZSqVopP9yVRfYcSSdWBcydG3f61wYxZJPMB
1142	B62qnSdNzb8icjWPiSsxgKfB1RvD47wLf9aYfVRd3HYTk519fhG8RUK
1143	B62qjNiMHpfrTemjZe3BYDdLfeFP9GGtyv3dnef7Kqx5vmdZo44mbJC
1144	B62qndvr7iZsJeFdeYVGYXP6oJY64T5BHjPBTSrfdHrwkxuEYCfa1LF
1145	B62qovdiupo2b2UxNhASffHV4CKE5abZD4TmSdSJZzf623fkrgLvouR
1146	B62qoFmrHvDzz1H7qztEkvkaqNUbGUCaZJJJjXb8xMmxVotSaWDmyMw
1147	B62qnkYYpjAHWvWkYsy7ANo9omZSQ53bwhKgHXUk8g2XANkjEq4AfNS
1148	B62qjMbmoXjUXSjqiR3z9zn8uSF62kExrbQ1mQq51w2ztVbSgEZGUmH
1149	B62qkMiKSD9HWrAc3oFqYbup2vVXQFDSrSr76zjbr6yExZarEJk5jUc
1150	B62qidGPfiiweETgxgkTrWRY7yPTS7MV2zz8M7RdKhuj3sAJGFDikfH
1151	B62qqEV4oP7w2jLQGckvZzdWjfdLKySKHJ3tNU5niRjpPD7beYumWTB
1152	B62qpTThstAYrb77DYCDygGW7vi1vgQ7mWNskcVRZ6kT7yfmHSByzxt
1153	B62qnMQ4Jd5pzu1XhiCXQBTgLB1HixygpaNAgVXMj6DajQNsEnEJx5S
1154	B62qmCFjyTQ3m7GhCcdJTrdggMvdbxJTiMFrsFeZAdoyWQk9DsAjNQw
1155	B62qrVyhLi6qSyAs2wzdcRB5EMvZ51cn9WQyQtM2M3igu3QKsTwGJqd
1156	B62qrVoMR3KnkvRwWoPhdmKJgegUwBoEnaxSpCiMeeSZxZ2vWUpxFgL
1157	B62qnTX7QhTmAHvbSs7dXa2aQNepP9raeqTj9fVJd6DQb7SJCGsUf1p
1158	B62qmojeHVL8iTWyaXiFEAoN6rbTFCUpP8FoVSW91P3WHgESWepbodz
1159	B62qo7fTZ4RJBJZUeHEBCmNb5jdShrcLPZVs6YFAYvWQxb5VamMHMH2
1160	B62qkwKReBsmE38P1fbWopHTRXBspPRDLXFs7pJEKZKDDjsrYhZAjHd
1161	B62qnwztbd73arnJBo3Zjqw8adn5xvcc2nZX9rWbGRucd2a3rUop2M8
1162	B62qqxBaYdaYHmqEaUvdwGzjiZJsDqySke9FPDr5xBxk5xUHfTv7buM
1163	B62qobkdtpag6cZzbkPBCGMxawPjHcBB82ja854Cz8qS8rmy2GMVns3
1164	B62qjz4dmTHSvMHzDShvrBcq5pJERKvZFqmJj8jUGiSAvNiDeApnTHF
1165	B62qpnWSJDnXHLWU4tSnmsGPLpcJRd7iT1uMvfByy4Xa3D1GcEkzVRC
1166	B62qopfSgwEn28YdwZHh4khMy3KEG9dy8Jfrv7cveUJw2sHzSCnWoqA
1167	B62qrEcZfLWiRe3WuCxvmm7oBZSURzBKNyphXMdiEPEEViq8JjXWHNj
1168	B62qnPhXw9uumnKzcC42zigqB8KS4LXRUzSNKR5EfFc3gs5ZVHmYgTu
1169	B62qni7tpQrD2w6JoMSMKDTa9wXR6KkDMpCXDSh8h7ki1afVmkrnvno
1170	B62qpNpan4tw9yvUXvjN5ScB8Sm8T8Vwf4Vc9n7o6T67jvM2VMTynAN
1171	B62qjDRP6nNDtej55V9tdmWhMtyjXuTFAHHEH5L2MW2nQ417wP4a9Zq
1172	B62qj7rKdAf1JfwV7PkU9gvR7fjLjXuEomU41coasvPEyY6PajPmrLP
1173	B62qnkgx9qj5PGBxiU7e6uHqEbKpW2AncbHP76LbYFd38DQK2YagZ8V
1174	B62qj2xi5jHnwJGFVnB99PKJGHibvd9XgrrgyXh6aRg7HkXsJ5cZemS
1175	B62qrFq66RPg47pcfMTyLFdBYWXRJaSFBfHhW5Q5Q8kzvomnJ6v4da6
1176	B62qqQc9UycySBf3ivyEaFh3KzFvLFjfwnKQsVne6VwSdAp8nEjst8S
1177	B62qnzD7DZ5jci5vHrKCuJhmoHjwrM4pAhuAiKtQBD38h3SRKgixaV8
1178	B62qmQ2n3jXzMqq3rwuqKwJXWYBRZYZoWJP1RCJjJbwxMYBMRNyM2bQ
1179	B62qqbgxBFE8zptNynKQANv4XXahadNZFAFpATzAoQYFZ6UFaKdghk1
1180	B62qiYiBh33hw4cVuP1RW7RVgWwFkLC2Q4DRphdHkaigQSJdneCrUAs
1181	B62qnDCGgbS3RwyV1EqGrktyiirSKr1WPpGHz4kA7EXXNgmaK57QWrL
1182	B62qp1C4ed4d4T9Hjy8ZGtZBoy2a3mubM6Bxf9o45LiLfBN5pbTMu7P
1183	B62qpfLn6rojNNJdbg4CPpVbh2psKRUf63A2UHyy35PxYF5gBAbaLEN
1184	B62qnPXW32xnngFowoZJRQXZviac2QvecUzfTfWdZCwTZthRzURg4wM
1185	B62qpnwuE1EeQHNd3JtJ8HjuK5VLo7E71J9oj2V3UCh37bjC8xc1kKC
1186	B62qiZv8fWPqH9oCUruNLuJaranpRAXeYzBMpVfZWA8Ui4bvZiGtQdT
1187	B62qkrhver9hVfaAU8hDgCqqtk51h4km4LwzSpvfxSpDWPQqk6nhdo2
1188	B62qjS6saLcoHU49juMzdzYahEsVAu4kd1snPmCyJ5yrfu4zzVgixZC
1189	B62qnyMshbjyi4ZrnX8SMKSKeEq6zXMDgnsmfVsoHQvSi4mT9jfpGSu
1190	B62qqoKGQqxvrP3F8JQDubvLednJJs51oJSkHPnJRZPuwL9FT4oyN1x
1191	B62qp1RJRL7x249Z6sHCjKm1dbkpUWHRdiQbcDaz1nWUGa9rx48tYkR
1192	B62qpCFiMgogyN1XAkRiS9R19GBShquY9uv3WK5AhLGhrufvdM1BCvd
1193	B62qisTrSDcz6mEtrzgHN5KxPJU6pf4G1v9vb9PMHAmnoRTWWqrAAxh
1194	B62qnAbmwZzX5HHHWwCaFJRahmBs9BT6Kj79tvd482X9eBAr9M58PrX
1195	B62qmadAHfyiiraNwvXhWC7g5q9qT5bkjA4FU35kycMrhdrEJjguJnq
1196	B62qrcVPyssX2RkRPMoD9PiKW3g3yVdAPaL43UpoT6cvXmNqzdwvLzQ
1197	B62qmNSqURW1RVAaKKuNtVqyrT9DcBD7PUrXuUivfcYhNA94ZVmeSvx
1198	B62qmJMuRKGqHt9ggz1ms66QsgVJT4b5bzA64EPWxUAHhztmNhGsnLD
1199	B62qnTWW4LjADBLy1wZZALkzHrMMGHPLu7qbGNgFpXyxUpRNHTc2Zm1
1200	B62qnz8HG7Z4VxQFhL1XakcCdAmz8CH2bx6YQJz13kcQrDV3W5qag52
1201	B62qnNWzsD8REZADYAEPZrgGaTdGnSBaNDi2HyrjcQSoGfRbBDWhWk1
1202	B62qnSrLh5JauAapgnfjqrB26Vh1BQmddaWpv1vXHkCjRTZFh6p8Qpe
1203	B62qpYqGMW6LJTduabsY8TRVbkmkh1vCNdVuyx58vvTnvJHYSjXV8Ci
1204	B62qpix6rNZVY7qhMDnVmMjCGuA55TGmco7TFuEPuMWrxruhWgu25HZ
1205	B62qrenUVqQeRTNmeDAmwJcvZVFfi12m3nt12PkHce1vgm6MMfoVPuH
1206	B62qp4fLmc3ZAZxUEp1PFkiepktWS6M2UcKrLqhUmLr96BBfPK7DUdo
1207	B62qrSbdso96pKAHdpMTTe1AC4QDGUYvW87vaEPdyAjWLdhryZivTvv
1208	B62qpKBNFBCXaFYFyGNq6PcRJFnkeqt1pBTDv5es1JWy6EFqpDDRWfB
1209	B62qj92oA1YvmddEq3MTSQSMPumQ3PDwhSaUQJQsib6ZFaGpWhwHsKG
1210	B62qjojdRSc4L9z1EpqiHAXgktyzSpL5QTUdJXLHQ4Uaj5hDpScbsMC
1211	B62qpAZLBaYoBqyQ8fqBc1JZgHp1KgAzDPiYeQv9gPpfPFw3hzPdZ24
1212	B62qjNrEEk2fR2T7TjtnFKpQYmZPU9uCNY3Cf5dfcKf2HjzsvPe51k7
1213	B62qoXrSMa8oXoXX1K5rYJuzYNXwQ7wksCgDRya1J57HfcxUdTMb35F
1214	B62qiw6FVYgc41gJJmh7w8CTQH8vd94uVR7L9j88xNrhGvZJ5vS74og
1215	B62qqBvBTSsG368YAxxiHui5KKSd1NYkGjXnCzK6Ud9Spnyp9zoWw7t
1216	B62qrs3r78SahLdnu5RpxNVMY5ZYhkMwmjcsyrXrWbAMMSHjC5U9Eo3
1217	B62qqpnUBrffgQR5YCNUM3L87jLCMJ98oxJxvwkWcBM2efdxjjGgca9
1218	B62qnbYZLVFnvcJQhTUT7moJGfRqKXG2Tu2Ve7jTwZ67xBa56g5pbPe
1219	B62qm2FvPP1X44GPT9cpZSRtmHkNRGWYFapWzeoj4u4XHSm5pNa3iFi
1220	B62qmwy5M5fyZ7BQmu3sh34gzP7nAoQrhqjaQnXd8aRqHHAXk7JQUga
1221	B62qnjNWCVvmLezFUdj3aRCxKp8HNbfbXtU96cWcvNkDTkG1ownsgcZ
1222	B62qnQwyE46zHA8FYGVkuyoDJa1S5sLprfGyNUei2RHs9YU6m954p3U
1223	B62qoZh57V4rNQ3FRv6tD1pc1MKQDmVGwk6R1qnKWNV8H7sygCVC7Gx
1224	B62qnQCf7ccbb8f39jDzKT8kRNq2939EpPaFGpaQ4agUuy5ozytU79a
1225	B62qq2vc7VoZ9vGxze3JfekNZqfJuE4Pc152EsiLYf7xvYBQo57rFJN
1226	B62qiYNLfwY6qLvuKLEAknPH26uTujWagSnDfGVfzsDfk39dmnRRW3D
1227	B62qrnd2kXPYFuVaBEQPApirUvDAGfdswR28XsXK9P5qvAkGkRbxBbV
1228	B62qpUDNRQosRHsfJBsH5MLRkbJ8kRbPUHKQBj8Wu6Z8VUeSRKJT25j
1229	B62qie4xN5VuLntjGz9Fk518D3ExeeDtvhbJcJsSBfTMQZY7sGMDRKr
1230	B62qpdXgX5zgSthWWNGHieRp9oP5R18GS52mfFsCz83tUrb6YgMVQ9B
1231	B62qiTY8rERRoGZwfVDxxRSyFBJCNht61Ct3HpTzfm5754gfPqE5pxx
1232	B62qmdFb6jKiHqzf7h9B2FQsdtdqvJJ8uiWV47YKgJQ6bTAhNWUgGm6
1233	B62qorY2JaxNFKJDSCUUipRSAA9Jha7rw8RzNxj9zRPHsChF8osV1kg
1234	B62qqCh5YcsZgofmiUdHL7GH6SSgKq3xFFafu8B43vE4kBo1ni8qset
1235	B62qoakPjhxKKgXAJ8TPULPP8rQWQFjAcBotfot6Dy89rzsCKUfme95
1236	B62qpVvFhkeTtSSAY7xjWAx4EjQXZsttbNCSdrbPsf9gcuD1JqbRiew
1237	B62qmAAFyvjEEdogSJAU5kxnp4ckdfL8ymcBmg7S8KmtVAaMMXbWGbi
1238	B62qkjmv4ZLSL1nDp3EhHqTvsey8qk8UVb6pjERkhSA1JtrRihqw5nF
1239	B62qppXNdhrxsDKu6bLguRAzrAWaEUYzPZeFrbXAwtGuz3Jb4sHMXMz
1240	B62qkam5V7xGsozwyR3EJoHQzGF9oMrWVryPsyzkYYfeDbg5kEWdpQC
1241	B62qrrLTwkCgPNmVqiAnjjkwfu2CxzQh8dgxH8Xp2TdwjpdsFQqX1i5
1242	B62qjTastRs5hDSMrFvic4sTxKdiQ9Dr72MSg1DnSVpZitcyGg1uVcK
1243	B62qj9YhQjWNN38P4AYCxABa7bYziNA8xoLQVDoSM5ouNhfksQSZrTV
1244	B62qiyrmLzu2Ad316mrmG1zw3wTfAQ2ZaTxA2JTb27kAQHmP1hjvAQW
1245	B62qnXpiGdQQ6athywiijFWVesiFZdPw57Wbty4CfFPhr96NLooSKSK
1246	B62qrKpENNvYAz1CJZbkBTkJGN1WGnbYPRgLN1aPXUPSEcHVfzrEJYK
1247	B62qn1svyav77n4ZvEc5uo1oHBaVVXbcV4vML6pgML2mnSi1VCQQN7f
1248	B62qnZ8ngDoptzYHQSoEMYjefhcnmSPBdEEnAzeztndLELwQQmjKrUK
1249	B62qqntBBqvFYWPJibxQcY8GQ8d5HKvshegCyyioaLcHAAkNT3DeXvC
1250	B62qmLunRmJHYE1N7B1xACrwoYcazR19uFSGLij2xGUqfyEhTQno1ax
1251	B62qm9rEzibmu1XJTn2CceCJhSzzT3nK6FGHkyEhuNUsRkJsCgYnqaz
1252	B62qpPQiXis4sTGj1vHqtwJvRhVWXLZtDBem8bXJBFGUr9nS3CV12Bd
1253	B62qkaxz722NcaLjv5VRihiEQrLGbn7CJMdZe2AKut5mLx1UKRhdMEW
1254	B62qmPGYt6QM5SNTmTfFM4JtQXhdEnMpo9joAe9vsEV1ipSU2t4BP9H
1255	B62qkDDA62kx6nVUJyGh9nuz86wmYHASu71dnrmeBMd99EowgJ9ZRFK
1256	B62qs2A9uHKFAA1AQPv113dReKHduJfQ3Pg3WDyUMYQmgk6pYBYGTfS
1257	B62qqLmbqTN7FkEs8dP2K7gX5pDUHJcwfEeEDdfziXowCrnyqpYEhwM
1258	B62qqvoG1UMgx2rvwBwFX5bGQmt4zLhcfBLB54Gf6YMbhDi2XzzqfMo
1259	B62qryctc7Uq5cq3S3HQfLM98tPzBVU52eF2PpxEYyEoHxDtoBGSs3Y
1260	B62qprdWQZJDnhBmWeSE8TNqSZYV9oYRR6YKwvabSDPJuZGD62gmu32
1261	B62qoGGexxYTFQ2A1BurUMJQAEF1ZbzxtJ84iVCooRTn8Hd4q48MPcP
1262	B62qjxgReuj5FKdrMw3i7d9A4yjwTvu8mr9roy9f6AUAt1orHEArLhC
1263	B62qnGgJ1AmXjzdSWH2327MFSAWKPuB76L7yk5cRqNS3WC5BdiiyLuH
1264	B62qpn33ywugMMhgCfMz13JHotUtq1XJme426v1Ud7DatcRrKXQgGdp
1265	B62qoGveNQGfVkAjvZyjAdQTddvdKVFuS49dndZMzBZLG84jYuLBV7s
1266	B62qp4sJA9R2E7pqCKf4LaC2UrWVrKXAWcdiNZwofZh3XqFFZs3MVFe
1267	B62qkPLhMSTJ3GXa6urmWQZf4pr3387k8cUsLdhDqtcPRiiLZbV8uCs
1268	B62qre4CXp2S1DDnzPdULW8Z8qbLyyNvYYm6jKmKHQmFRDf8rAtm11X
1269	B62qmFMKE2uti9wcEfR5nNAr49x6QeeV2nhZwHAYsFXr53GDqT6faNo
1270	B62qrmRJosdwWKwFXjfLEA7fNaPDkAiSkGmGDLiPQkphCcnC7agyYEZ
1271	B62qjWT9QQ9LGZoLqLoAXjefPKmLFXd9hQgEt4wUrR1Xmqy5oJns7ts
1272	B62qpziYULs5tfkWNdkHcDXd4UL4WCSXwfuDh3pwMFHzmMoGXwUfpbb
1273	B62qri1DwUjHPGLc6XHR6VS7TZE34A91RYQHkH8KocpjJUMRRc8MUhW
1274	B62qpXyX1z8kE8pvJgfDoSsY7r8yimEqWzvvSEw9putVG4TjFrdATZT
1275	B62qmEcfvLuJYd625PHZUov3RiMEt7Mayed7ywkXoByCANpGPWVnCLF
1276	B62qnJfcBL26QpmiTeMx5p2m2zzyJi6CfBnqLbsBRfxqE9zxZFR3sB5
1277	B62qmsYXFNNE565yv7bEMPsPnpRCsMErf7J2v5jMnuKQ1jgwZS8BzXS
1278	B62qkpvmmCAXozUrhGaEXm5GMVtsGb3jaBPjTtVEcNThz3QjxZFqneo
1279	B62qk87jq51vzPGrwafSpPczAYGZJii46PQx362AbqYcDAtG33DJVgS
1280	B62qknFbTU4AAg5htLM8Jm3UmodeZmNQUD18Gh5ZPCpN6w41xhPt1PR
1281	B62qm2wh99cMx3U94SnNKPCo6yPnZM49A2J6ad9i3HX2o5TucVZJEGq
1282	B62qiWMgGFfnWnNS2XvCJhxmaLHvWnHBXr4EK3MopXKzutq4Uu34QXB
1283	B62qkNm8jmhLKWhP5Qr5LL1RtzRz54rhZjdLxCX1nxcgzs6EB21jrdV
1284	B62qmDJvagQNBeQnr4D23Wa68tZJG2qniicGNTEaNuv9tm1ghxJpUYa
1285	B62qkSXoeyA5TxWqb8CFyrBf2yYDwRssGYxpuYzUJSL3ttDgpxDobLs
1286	B62qq9vZuW32TxPcWysNkYdDgFFfoLoNBFhdNsHU8ZzgLToYAbFFYxs
1287	B62qox5t2dmZD2DbUfHLZqgCepqLAryyCqKx58WJHGhGEkgcnm9eFti
1288	B62qp2ZguTDrd4zqZQLCS5ZShQQNgWwAGBn3kbcgjLX9mqtP37aTpGm
1289	B62qr1H1V6usV2pVMP7L5sUzFxFyAfNnXWzGVmwZj2puLdNW68fwEES
1290	B62qmUcnbr7qd6UDdVnZutKPFagDQDyEB7NTbEFJTV2GZvWquyMgoQq
1291	B62qkw8jyHCeBhWDpGXVw9yKpm9BxBSWWqVBWyh4XTHoea8kayfKhzp
1292	B62qiap2uo2Kt8RzoupS8jqCvAKiUZZmiXZUJM9gpmc1zq8KdFtKnYb
1293	B62qnPcQT5LEny2S7LoHpPxQvKfo3Ua15PkQ4tUP3CSteXZ5yiqaP37
1294	B62qqYKsXdpf96KhFvJpeHwDCNE5iUZqcPtxca3WxL5HZQ2HyTj2g6K
1295	B62qqttd6WJbThh7wFrQThWt4PCNKWnAyrXz2Mek6hwz2aT2k74NzDE
1296	B62qr4TM91FYFCk4XqLsgaHrmaNrc5FojZhWbssRsmkGT5zycZhhyUY
1297	B62qpaGDCfgmrUhDGQcdzRGCtCcUukU8bptsDp96fdovy68HnXeg2dw
1298	B62qoBFvWZADREXjtmGvDyyeginMBNv9W68wFZkwD5pfbphjyfo7MMP
1299	B62qkVsDvq1wNSwwi5ic3UN9zxUekQizbXCccoCxxTAJUWJFDCPdN63
1300	B62qjGWAiMSeL4HqeWozmHuVKjhP5ky2iWKv934SeG53jTESBJgg4nb
1301	B62qjtd2hibm2T4oi8yqVtZVt9LZi4KvH1CQX8eArTmJumjpZVogMJ6
1302	B62qpaoBemteDmFY1Usjj1PQUnerArwa2bdpqMednXbuD4aHT1ryHCe
1303	B62qpG8jpefptAeT9en6WoPzaW312rMJLwoL8pRmqcS8FCKiixRjofg
1304	B62qo8J84nSRhYcZshZGDtewgb7R1PyLz9J28PFm8B9ovfh7vu1fE7N
1305	B62qku2Fq2gbLmFPi1JxWxEb5QvX4Qy5bwxuiSG2BoTRgz8MQKEpAUt
1306	B62qmSy1QA6Qbg6Pi9KwudDLFduUGt9dEFkMVuqJwzcherG2fosok6Y
1307	B62qo3N2wRdhBsCqgGYJ83Pbhei9cEvMGrUL9zr6NNbbMq6wiu2jHma
1308	B62qnwLbBcpuP1xFPa9rZte2mYAKLijUtxnhBqNh3fxDifKQj3T3JYD
1309	B62qqMrZUfkMKB8d3i3Wiu8CJzTaFFk84um32QfwuEG6odySYy8D74B
1310	B62qpYri5rQK1u5sjVSh9kNbDRr1AbHNsEQTGd1bEg44UJKByLCPnuX
1311	B62qpXM7C7RW2PsdJz8EEYbGqTXhPvVW9RQQ11Ctc7wY8DbhAjyJJGT
1312	B62qkH5oH847YezFUPiPNq7LbMaNDpZ5SBp7Wp3maPU8DaejgCG9V88
1313	B62qmKY7C4nK2rnjQJcxMFJH9fpPkuAZxUL8opGzqKPrZnrnaH14hd7
1314	B62qpB8GXzKSK4ASmHkpMS8UpvyRB3FbMo8Mjhpzs6SPXaEtGnv5Qti
1315	B62qmq98UH2tX9NiDw2AZP5aGiwKfxLnVTkRcozgbRZ3opPSPkuXvqE
1316	B62qp3kfaMpfr2TB1UizLUBv54BELBovJJWjXjVMfFiJfY7AuEZm6yV
1317	B62qjk4cMyZCGhftrDZh1tQK9w7c86bQ8m7hRULumwhpC95Tz4HaaiY
1318	B62qkV6HMEh7SYKuLzdpCpx9syw9VDVNGR5SBWVTbQJV9bwWZ96iP8u
1319	B62qipscEVdb7J3U8ig46wgxc5jVtaqnHrCQLnnvkthYLFiw4MPvQxY
1320	B62qobGqxagMKDMP2UiKCHWj2dZovDyBtdDiYYiYGSg6TQ8Rxw5fXBj
1321	B62qiv5rWc3VMyMUP8yc1BN7KZFT3MH6TUrRVMHUZkwveYTiK3YnxfJ
1322	B62qmurvwu5wPC4X29DGAnTTys7CXpca3qTkJKw3qh2F2PmdCFkVcQ5
1323	B62qnEjHVb5sFE8Uh8TXs3z7vjdsFr5B63in8kkBkCp5uA27qtiiYCf
1324	B62qkR9hUHJVXxitqdVAF6bgefB2iCAXqMsudA75mSr4VMY6JSEGLJe
1325	B62qjzN25D39t1RRCZe48NuhcmHXGg3t3ZSDUm1K7tZ9cBvkdULmhRv
1326	B62qjq7vHyZM1YdZsQo9C3oW2QfdP1494iYD2Hs3uB5DSqGbk68vgCc
1327	B62qrxHA9WaYLMCMmq89Knh6kbm1uDX99zD2U6DvVAH3JEXYqy6eQuQ
1328	B62qqFY2G32WGjvu4hDDHFzXgJbdvCbQQmFjraPnch4uMW6eFX7qvLe
1329	B62qq99djC5HtNVdiBFZ3UN9a1Tn6THZJUcckEtAJon7jJzQMKDU61G
1330	B62qjKzYp37w9XyFea8TA87bGNK1yXRsrZxNJqir2WTorTHMD9Jkh46
1331	B62qrjUz973gGZEpJwqQJ6MiwWscqx8k7fwiezoEdU7VBnGQ9M23QPU
1332	B62qqWHppuoryyeeigDZu8tU3xbse2sut7o7ar2vh2X6XUnfaDn6yph
1333	B62qiiuXuFzqpRaywDot8irDtZcWK1PY7wBsxHn8jPzqHGMCz6C7M2J
1334	B62qqSHhnQr8mnbZmMnwgPfQT4PZTH9xupA5a6uRKt1Zdf8nRx2U5kF
1335	B62qmQ8943HETz4i2PFsc9EYyNAVrtFYJPAR6QMjCk9hT3DPgQmNgJ7
1336	B62qqLFzJe6GjhBzVmpm4VHvFWwFk4n4F5Ci3h4DHVQgfJvkWoe9sYv
1337	B62qnL1ks6vwcqdaAUSXrgGEy22kZDoKZRFs2NhkT7SuKMzevnCZUVG
1338	B62qjpFbzR6FX2YJzsUcimJCTjMsozchBAyrDgBGUZnmEwCAj5zciYn
1339	B62qq8aDzB7JSJvK4fKAKZpMfeNBkVVdgLW256cFDEWxws2gdCap6Vt
1340	B62qjfpVTExVXjaCDEkK5un2qUWxE7QhD1SiYzMW6SED28WDfXsoDi8
1341	B62qpxwBDbjGQtQHdjBX6SkdM4BvcoS6F1U6hrRa81M4acLoNPMkjYT
1342	B62qo6JMHe2uf5Cf8vQeLRFdufJYxNq3XHW7rRuTVriKNTpWpEkbpok
1343	B62qkcf3fkdzyw4D7GoMVwcEbYyoV2xd32iYfcK8iLWs1o9UD9oHyQ1
1344	B62qpFfHEARyRrdFLowd7GSkw2KTnZBZS8zWkpFMDxAy7X6Y86VGU4a
1345	B62qpoonGkkt3p5B7YqiuaVD4tr1LSoktxLxQd5UmWrPv6qbZ2JvQgv
1346	B62qjduxMjec8JnUk2P5sjLWtxuabDPFvyrbgwvNZ6Vg2T61ZB6sa5g
1347	B62qpxNPYzKkCiXKN7UNTx5MG1Vaf69YMFBmzFCU8r6YwVpbLrqBp3V
1348	B62qjGio44RPhEjYx1btYmPhAnXjromtx3NgTdAchx9BuaVyT4tQieJ
1349	B62qrQwEGGVZszUG5taKCYxdM1yf9sQLiSzNtur3u5hJ53osezWP7V9
1350	B62qkHHBnLpwcg1u4jgajoUUoSXHxMFEfZ9ji3JRbzftY6gTmuYZAxH
1351	B62qnhrUFMCj5n5yiPuXcQYqKh9d22ZWMW9LNxGdF1FkhqAT3B8KmgQ
1352	B62qojV8copSeupvVFup3Etn5cHWkTghYkSDjYzrge2oXQNc1y69jj1
1353	B62qo9nA6D6qXLYC8NP6YonkfaaFHufaa19MJvCNL5vEikJ89WtQ2ZR
1354	B62qjkhkXBPRuQ8eLEvoXzEHegQm7LoRSF1CksjYKU8Vgnzq5qZh2S7
1355	B62qpZ5o59hbZ7oMhTSiNBj1cz4J5SsuHa6hbsgtXsbudFiDsAVrbzz
1356	B62qrtz4HcUf5M1DY1CPyGcRsKmrusriSKEzZtVXJGKCtWPX9AmsMxw
1357	B62qniRCXGwymuWvRKe2WBWNVrx9ht8eZrQNCzGdtW4N7Fqj6iUfNqJ
1358	B62qkRewwZc4NgtjBS4HwQTfLt7t4cSCaBhZ3Y8TQAgHhpWZpKuYxA3
1359	B62qmbZejY2rjWcX4nnk1Nsatx1JnTybwTPTzCBNXkgewtm9VVZR6DD
1360	B62qimSXq2Jp9Fx8HGg3nStk5UCAQNKhpbB8M8QR787RRmpHKGqgZ3P
1361	B62qj6WR4x3YBiqq6mXwxEtg4EWYJ2ELzvWe9bZuuQ1m6sCpjNv68rH
1362	B62qnyqqC5NCsFMRRYyKkhwqpxcmCLUSmpsM9vGQhFRU55Dosnt4ryH
1363	B62qrYQpG9xQxD78Jd9BJfNRYx9xmrcZSnCgY4gC5aRr84hQo725NCJ
1364	B62qmKJxgh6h4i56hTXmkDL2Xpesm94NNm2Ev4ySSA4rCE2Z3JbfZhc
1365	B62qnYqMnurSMbTWdD2BkeQLudy1RMm3eRc7DeBuG8QykyJ8gZ8Gdv4
1366	B62qo5AuWQrpYPUckr6snpnUm2TJxPjMN1wBcJznJH1dzYmhbHsbj9A
1367	B62qkVvzN5z28sYfyr5TzrMhH9qTsnNQLttjpJjzSTswNUZgrWkjbZR
1368	B62qohPAx6tKFDmVTLGepyruaJNjwA2k1mfnhBbQ8Tu6BeH6Rts99jn
1369	B62qiUXwV5V9ptLxcEerkYr3kY9EGmhJZUb1h3ro45BGgForJSSmknZ
1370	B62qodkoaX7oEbwfeCYfC7MrWCLgD6w5f1HXcWa51RZNk1Sf68w3x8i
1371	B62qpDQHkdbMPvWzHgUcrxtJXNsuEg7tpCL9irDMNZngAJJR6Vsnv9T
1372	B62qoNcRg1LV4JqCJ64NWLwPsThRg7GJJQgvBiPAWuMnLDCUXigXV6d
1373	B62qjrMUVbWBQSPL8BgiJe7QQJ6RvtBSckxeBGt4C1YpHdHcTGjEgj1
1374	B62qpsKUHUnJfmEBWiAQLevw9dec5fy11oeoDYvRVrRjrJkjovrVDWy
1375	B62qimoHcDpJQk7onuWv9kco61Uyg2qTridyS3XMsp6DMKAxRq9uLa4
1376	B62qnQ1RWPv6Zu8W1XUSP5tKuxAQPaHaZY4MdTRt6KGZzgvEquz7yxK
1377	B62qrd6hgek7MF3qEb9AbZp9Cjmsd58xSCB1J2but4F1vmsgeQ25N2e
1378	B62qjc2RhgiL8WQomzjsWkwKstX78Fvkwp8q4HLgRvM2tVvxc7nxLvj
1379	B62qkYD9MA3T64UQ3aibcuZyWYh9M5AvWScjhTjxZ5viuY5N6wrG4Cj
1380	B62qig8xJD2GVHzJM1ChEXXMUNYwoUz62TY4CPTv8sf6MCDqgz5Wt9s
1381	B62qpTmo9FwpqAdRGJgQY1kuoSahVc6HwPyPQy9BRYmZL7G2HepTAt1
1382	B62qq2sBv1DpDtFueYmcxw4QP6i7ykKJ8eMQvHHMLxM2D9nh49bxLok
1383	B62qrnhMZtiz2P5AFEjyS8XTn5mQfJLFRQ9NkZTJhDZTAi9ERDDHv9S
1384	B62qmZFJN86FaPewT225BQUytfvncvJ8kwbF4zjbQHvXoa6o5YeSykt
1385	B62qqL6fuqFgufJJ6xU6waiJw1xEQugPsBJR6zhVHLtZ9Hp7R3BriTF
1386	B62qmT7Kd5rSF4kW48L9xnoXTUwW35VhsCS4wKitBHMRCmvywYE7iy4
1387	B62qqqbrKMm1aF2pgeg4YcnCuYTahsR4eMhfbL74fZmo1f27Bhi64hL
1388	B62qk9RQQsLpE1i1CJjkN6SuoRefXg5X17kqvvZV2UMysW4hr9CCoFw
1389	B62qqUPRmvN4SdX2XAa9z1amQJjC5apzwtmwweqVWFxKFHLTf9b4HVW
1390	B62qrFTdexNZeedkMCGSEUDtc14atEyevSj6Bzix1UUacaXmiKLsggw
1391	B62qpFjUdtZSGzXa6pYJuSv1R5vxJPorZLPgui8Gfg4YPrYEeL5pyz3
1392	B62qiydA5hjPMZ8wm7WkmZvcJWGio1A3X91Cu7PDP6WqqipQXEZu1gH
1393	B62qqNHRcLYT3HvUHyQ972BeaZi9Nm4GCRWj4uUbB9iAHhc7ZXiBmFC
1394	B62qpbZkvpHZ1a5nsTbANuRtrdw4YraTyA4nvJDm6HpP1YMC9QStxX3
1395	B62qrusueb8gq1RbZWyZG9EN1eCKjbByTQ39fgiGigkvg7nJR3VdGwX
1396	B62qq8sm8HemutQiT6VuDKNWKLAi1Tvz1jrnttVajpL8zdaXMq6M9gu
1397	B62qopHVr6nGCsQgrvsBsoxDm1E5CEdMkDSN3jneRnxKpR5iiXnTbas
1398	B62qre3erTHfzQckNuibViWQGyyKwZseztqrjPZBv6SQF384Rg6ESAy
1399	B62qoiM41U5gBnjujQRgeewfkK9VmgVT8ifrRRwAsqBUM6pdxi9ywk2
1400	B62qkJJpeGWtxZtJQFXSrM3h8TXMfNNNuG8g5mLaqU22HfWQBNENe8Q
1401	B62qmM3q3Lzur1LyRy9zaw5C2KWQGqpv5epRHFz4t9C9ZNJGZEhAY6D
1402	B62qp8Vq6n4VHq1LUm9Wd5QKjpKb7umoZ2oU9gpJYuHNUc7t2HGhGUA
1403	B62qmFf6UZn2sg3j8bYLGmMinzS2FHX6hDM71nFxAfMhvh4hnGBtkBD
1404	B62qjCuPisQjLW7YkB22BR9KieSmUZTyApftqxsAuB3U21r3vj1YnaG
1405	B62qjYbjZC7DBP78LheCLjD8WRWxku6YzqarNVK2er6t8SQfXyk1ybc
1406	B62qrecVjpoZ4Re3a5arN6gXZ6orhmj1enUtA887XdG5mtZfdUbBUh4
1407	B62qqhURJQo3CvWC3WFo9LhUhtcaJWLBcJsaA3DXaU2GH5KgXujZiwB
1408	B62qrxNgwAdhGYZv1BXQRt2HgopUceFyrtXZMikwsuaHu5FigRJjhwY
1409	B62qndKKWw8NwfxbiQBu9u2hrDr2bRZtULC9zNs9R7SC9k47yGZQZ2d
1410	B62qqvSxj9WncbMkekiXKZscTkJFdLdEDJm2xQGQapDhmDJBXBBGBcc
1411	B62qrg5t4eAupYCF8d3TzVn3rooxCWF7bWySVmnyytjGTPT8ttLMAxH
1412	B62qnxC2WR7YbTg2sDpYudYTyPPJKHDy4PTNEF1DKHJ2Pw6E9YhKciR
1413	B62qpTdEzGyefcZduxfHQxLpvBUqVbxMGDjJA32nRN26UquTxPostRp
1414	B62qruGXezzHqV49J5e3qWfcpcugpP2x4Zi3cGQdCe6txLnLubJTaM3
1415	B62qrgdEGEKerCmJsAdPC8WyfLP9p5JtCboQmv8b6p2xQ2hRZYgFwQ5
1416	B62qijk9NLY7cqcCBA383RqqB52kPF5C7eeZp2NoFmJHZkndD9SRwSV
1417	B62qqXAGfDrLyEfz11N3DrFdHojimo2Hy3g9uUcSsPe7VCJscaJrS85
1418	B62qmFGqsBsaqfYGshobBGeGGYGgB2SjcoxVZZnLRQJdUPZdMvGaYRe
1419	B62qrV1D1bezpJjYrQkWc1QvmWwyATtmuhT5AEeKL9heLztnLbM4GFi
1420	B62qs2Lw5WZNSjd8eHBUZXFYyRjV8oKtrZMFDn1S1Ye62G71xCQJMYM
1421	B62qr9jmNyuKG9Zhi1jENgPuswFRRDrkin3tP6D76qx8HNpjke5aUMs
1422	B62qpZTtpZL7QobzPX97h1f2CNFchXoXc4NJUZL1xdvNqTdwR5NCbkZ
1423	B62qjBpH4zeWgy4d4p59qUXDA3DtYeCyBrRM286sdXZFw4A8SiswfBh
1424	B62qqch9XkiTS8BLUDSM1sayfXNAtnYnQFChktYG1bfCJkDMUqs98Xr
1425	B62qj1B9sNZf8cm44qk8v7LRAYyUVVPeqrMF5ETmdQ5grZ8NM9ingCx
1426	B62qjXTW7dMAWwRTnJD4U8HwN4ii5t17UnGANbhtzenJTBWSDESbQEw
1427	B62qq6FzjoX7GCqDY9aUP7eFm9QdqHpFJ8Aa5xB1YLj9GuPtsvG6Mp8
1428	B62qqc3eKfNYpdRByoN4V3BTjoPRgacLrqtx4WkBQgnVcQ1MHSWTyWL
1429	B62qne38nSn1gwHkAn9vPN5SZntgXg3cM5pfuad1zQxFRuvAQmKkGTi
1430	B62qpwXadr3bwPsV5M7NSTZUGRaED3FPy4Ju517PqTZWWfjS8h2dy9K
1431	B62qrvWNDUE6HraKjMNFDEZ8eYYaiTCF75CVNUXMsL7DTs4DYjfsmEe
1432	B62qqzq7hnj6Bm3pG5PG7ugGrTKaNCa3XBuU6yDV1XmqBffpyb8s64i
1433	B62qngGSkaZCutEntH6Qu7V2g7waodEDfjars9VRf591oAxvpUW9Mzd
1434	B62qnU9faP18C3nQVwGNxreapkp65v11j6JHQVMgZWtEMJcQW4x1HsR
1435	B62qiZi62RK552P54BGEb7saNF5mSVRCFcxULPvGVi64KudP1s7TSm6
1436	B62qooTeMvVnDWWMQW7wdDmpEm9ZRpre4fTYwr5JZE1yN7sBLERbMyY
1437	B62qnGLiPNy2WEC2QRxJq4neyPKScUnQNEV4pRaMgYkgf8PcCKb55y7
1438	B62qrRVMpryecmWaStfobX2dxRLuWxsbd54jfjZm9DAdBycDic8Ef3h
1439	B62qjceYTwKGRigmhy9A1sPZYsvgAxSYmVfkgqC1jUkbpLCsoGWHeXX
1440	B62qp7J9DJWb4y9BsXiixdRQLGvouFmrpyiv1fmF2vPSV1tXhWuTiyD
1441	B62qjBsp2zWgyrbaSqVMcduz7A5s1sT63epFUVGFRjCfjCzy3zwSVaq
1442	B62qpaqLZv6tca6KytUsgkBoQxCRc7cMRVkVYCWjyUFGegS9cwD676v
1443	B62qn8JN3sLVja6GLETxWdnma3hXuUP2WfUARkcLfs8jWqW4FbuGuCU
1444	B62qpsMTL1mTaQUQUTQzVM1qvyGTCLVAhr8whJc7tUfmnPEuZnanzUe
1445	B62qiWcbScnq9W9bhk4oLi53fyH5TL8WxzDG5cqMhbz4SUhz66v7izL
1446	B62qpPqw2hzqjtcqpEwvckfsAENgXUxgJGu8y3Z6Fzus7pRH6UaLLp7
1447	B62qoNBu1CV2UFJTvT7gfG5r7c4C5pAuLCw8yf5CSKs3qkswSQa6JFn
1448	B62qj3Gzxgb4G4M8CwZRXZPtmVwGJtGfVXVbpMrACNDSqQLoXzSQ9HW
1449	B62qny4snW5cBovDvVFLSipUMaDiu7xwYMrfbTscDLDne7enKJyGkbh
1450	B62qjWchpjVwmbEazciy3VSBZhJNVF28RcDQirLFpH2rvfmDrtXL382
1451	B62qqTGc21K1mJo9adVuKwRddiUD5cQxocu2BxaahQGfrQzvWBc7UYv
1452	B62qoRsqqfdfDb3s4nTgTVUQGLep77ZcoKjjWoyxspTn4CEbtBknDek
1453	B62qrgnUUduZy2z7zT8qCV8ngTJfSS1rK3Wh22SHUmrse3Tfqvrhx8q
1454	B62qooQD2NzgGaiHHmbdo4C1c8YcQi5uf3ns75p9xfKp2L9FagTiFcP
1455	B62qkueeFHtVMTKbwr13eWEMZmW5gYgeKZiGoAJM1qTs6oxAZKiNJTT
1456	B62qni2bXsMfr4HnT1RSYob5x6Cz2rP1zUr3sKuMSqrqt9jtJR3se4y
1457	B62qnVMHrtGPVRN3SrwyDzjbgBQhaFSgv16SAAFe5ddm2369KKzRn6d
1458	B62qrafvvcSTkGMpFiprxzDN8JXqoiyHSUQwUsKbRqrvTK1khb1HJyC
1459	B62qoJuLTSJt6fqkk2N2yntcPKSEb45C8HWKr24Wi7atzCzgeXjg5oN
1460	B62qk4VDCUCnX1TV7RrmBnSmEM2L415ucaAhyLBJu5xYNZX4Jx3Ksdh
1461	B62qqV16g8s744GHM6Dph1uhW4fggYwyvtDnVSoRUyYqNvTir3Rqqzx
1462	B62qoEAhsEqJLrLUNapSiS4hKXR6N9onXceLy3ma7JBkFznzXWpyPJL
1463	B62qoZHCPoNTozrDqDtj6vjY7MmD9ZEakVMxTR7btNnqjoKzUqp4EKx
1464	B62qkxZba8d9MWL9nXRvMaGJXESxHbkLhfogtqsCXKs8ueSZkhJNboQ
1465	B62qry8iJF3X2icdxsCzFz2qEXPUiu9HkR1wBde93bqgjvFzcRcFnti
1466	B62qmAok3N8kahogApB18ftPKLjezt3ydrHUj7qjxDVCEQ3YMvei4my
1467	B62qjodMvEfFUfs2ciXUekPF3f4ePhH3uRfwoRssh5hWF1Mr8xHjeEF
1468	B62qqKCmTdo7JJS6hP2YsiMoXvkpo7rcK6EsxBns3etbQytnoY8b49C
1469	B62qkfis9ADewoBbMAsdGaswbNUhAbbjJw91jxjH38aUriQv2dKL4xy
1470	B62qrgTTdsWFGQoPUFgKn64wX43ycCPuBFbf73M4oHJYHJfef7dvdhY
1471	B62qpe129AcY7gPkiNdStKxNtwQC9Y2ZyZCMKGKn6taZGCdTdBtuBYR
1472	B62qnMmqkKptkyQPvYmCAAEnbNxjjRkpFZJSJLBgAuDL2bURwZgXe55
1473	B62qm5ESJuFWe5JypXPQMyuw2BzkVXGHFgNBgeuvBnfiLKRaqYRW6rX
1474	B62qp6HmxzW5XXwCMiyZiJREoJ4b7omkNuCJiThVLNM1P3u1s1a3qzp
1475	B62qmMkbajiY3bdVRjv5bx3yxjp5sBHHQuu8M11sDdjtBy5VdgWdgTr
1476	B62qmPfsVAZ1bFqNM6KAKZ4LmMmyxoN6FhHyMdwSusZV891yvQachZu
1477	B62qpL4ZdJw8dmaD3DJQvKG4Ewt82va36rYK7BkkKs2SnkxzVZR5oBk
1478	B62qnYBehkVZzgJBCC5yhFyF2L7mMRPsVnKW2xpcWFVuQYRVgoqwDCS
1479	B62qjBxeuwxjcC2XRqw6YQnC5BHt8v7H6LS25iW6D4CKFwGYvCVqTXq
1480	B62qj5W8VBtyVC9j5cgGC3NTXGnQzZt5VYBCc7kMC3jDYciuiXYAngW
1481	B62qj4b3yw7bqZd2AKqYFedyL6sx4fF6GgCkzG7QWz394nPMN4EKLv1
1482	B62qrLt9obuWhsVgUsrFyC7AzQXfrsPzYtDrDZi9TJ8cvv2oDPVUZsn
1483	B62qoazqR1ag2hDwjkSSm6qV3eJtkiPvVPKhfVyeea7TehBAWu4dWJ5
1484	B62qpge4uMq4Vv5Rvc8Gw9qSquUYd6xoW1pz7HQkMSHm6h1o7pvLPAN
1485	B62qmHktvgpH1Kbkato9MCWmH4TPKtHWc8DC4FhQCJ5TpuZ8CXazczB
1486	B62qrLf5xV1fdE2RikXzzogaJYhPmWMf75GGSpJSG2yLiE3nM24C2Nd
1487	B62qkCk6fo42qQXowuAuaEjwDhSeJsgw7ZEohNkJacLfeiCikUb5W88
1488	B62qmLRLxC5Fx3cRmHDwKGq6psCbmXAYE1UsS4Z1foqrXCTtJuvTbbL
1489	B62qkXQoFvTuTH7ARfihY8XmsUi5AfCpZgjmeQnf7bj81oTdT4GCsh9
1490	B62qoev8sKidbnw2RmSAJ5w4SFdPvn88UtqvZt8GxHHd3d2P7x2Etgv
1491	B62qidz67vVjRUWi4QWBhE6i6JAs5i55YP1CuRsSNB8CjM4nttrRS4q
1492	B62qouvr8ux8uJcnZ65gLXy9ZkH4qS3a85mBn5kuXATpx6kSdbWfuCq
1493	B62qiYicQcKtuSqdDZwFkaMzMCtkPmmFuaPFy6ufp8MtpG3UsHfe2tH
1494	B62qkkAapgA9T5CqRDNM5X5xPuceWsZNdVYDKc3MgMyBvdjivTLDmvy
1495	B62qkoCsD8drVyoGsd7y31zBPnckxNjhDdiFMh3vHSm9kww82ohpp9s
1496	B62qrC14RL5ASE2Ep6sWmP7mb3dfTWy3AyFJYAduxDnjYYVFiPME7wk
1497	B62qpuNrv6pWhSyvkh3mCQQw2WcjEVRFnyGJGcw8QBZ7BexRCmgR8vw
1498	B62qojbGyQY7zXAwezuZWw5HUAEdsF5JnMeCYZEB33uvUzpenuTQCSe
1499	B62qmM9KDeqvu3TVpQStGJARgg7KppxE8UF3xMdtKV9TDc33kSUGug5
1500	B62qrx22PmRx6jXfvrS4amPCGR22KX6SB7NXvFLTuw9eDZYgVtymid2
1501	B62qik2auL1VbkX6fijdzwT6fGgjpi8caKUH6vbov573DbdT2UbQkDp
1502	B62qkDxbJZ1g7iER3Pv4Gid19m63wp5DKs7Jz7ELxVerWqWeBwrr2dT
1503	B62qqhZioGPLYePnwCFUqQd7WoHu3TTmZVAvwoh61xnC6VcWNqLMsCp
1504	B62qoTASPAqsxJb1kmDZtYhxRAuuegWG1WhzkxqmZVD3BmKLenPa3hx
1505	B62qkZuTU66fez9p4qwx2E68zggQ26etV6WDcnSx1vizfaLt3Xu4ST3
1506	B62qkG8Z6EVvYEZCPcvtNTTguKLnYk8fSduR5q4sTvasCB5k9bqpDW1
1507	B62qjWwDxk5nGMXN32ffuMpMSp3wPa7BLB3AXHH5EYiczcRxDTF9uP4
1508	B62qkxMXa9JorkHdS1iinLn5WwMV4dgn3HT63osBoFgQHYoah1MdzKw
1509	B62qocWXdgZV7hC7bDVbLvM2fAKZTFjVoqVP3ppJhpgeUV37Qem4PSs
1510	B62qj3fTBMfpJvoHTXPiKymxQcHH674jynkqsRjUw1bR12t2VCrW8ch
1511	B62qmgmWNyKRJz6m1h5EnEPSZqiUf4HNHWaPsH8XEUVs9whBo4okwyQ
1512	B62qriV8kQ9FzSRuFPXAjtZx8JcBhY5gmYkFd8VUxPVVSBpSb92V7T9
1513	B62qnUwCFGxywYr6rxq9Zgktbm3Jc5hdTChnwbjM2goJ4XLctZXWwp9
1514	B62qpAmXkj3fPExD9ASLbARWBos7taNoviawGnAeQWgCvNNnvj9Bn4D
1515	B62qnR2AHmcnyb7v3cVvuZWriEnArx7yMkXBcnzpFQXCmGxAAv4nJSV
1516	B62qs2P91UjdhngetBJ57C56HQ8t5V7ECAYWBvpkaC45ovXNgnzqfG6
1517	B62qmXMMTUuKDEwY4THkgX6fvDtujGNP3FMdiaWwSHkMsMM9NzwPXZ1
1518	B62qkd9DEVB4G5AxN2siEXVCgs6VFigNCecmU4gTizTber4hHexwid1
1519	B62qnvKLdq3j46nuQML7govR1gNqfBjHtv86FzmfrAU9NPGd9BSzooh
1520	B62qicXxuEer88smMkN4gPx7WdsUf4dNGh3QjfprXtB1dPs9ZARY1ba
1521	B62qqYv3jnSjWGihWqqiX482rkPJ4MyXDtGF8Uz2zh4UewKapdHod1P
1522	B62qq5YxMfnoC9trqNzXDrM46zheg4Jq7qv9WBUtrqMYedgtCP67XCz
1523	B62qp17siioFbT7ugFCJwtfcSn9SHFsBNAkUAxKjaFtorKqQ2Z46L1G
1524	B62qnSUbgFfPTsZGPhFU9hEy4PerBLCHVcTCYthU7BUN75nHiZQPg6r
1525	B62qnMTo6ii49AJa83i3i2WeG3bJN6WHDYh9K7BvKb42aQHC3Pibvxp
1526	B62qjPDyavWQPQEPE4V1kZo34gvffu1wU76XLrVuUSRMyDvrHxEPMf4
1527	B62qksN97EtNvQGzH2RAgnDR8zLAawhPNE1QzWCgPRcknyL6NJ3CCgJ
1528	B62qkBqSkXgkirtU3n8HJ9YgwHh3vUD6kGJ5ZRkQYGNPeL5xYL2tL1L
1529	B62qj2tZS6SxPMfzFAvVxR6ZMfryVotdhMUwPx1C3EAhgqFEJAAqUXX
1530	B62qrGX6VyP6BmGAMYzrvhyq12JDuCQHpuumme2St5K5nWgPiFKhwMS
1531	B62qrL6Pps4zCkefxTemCQMHyHKYRZ7DiAR8AxLrzhAwaAyJ6mqYocT
1532	B62qn9Xw7796dqjdmPRxzj9BHKjUwtGwovYpWXZ4EsSADVJrBee2pxd
1533	B62qr33YrdZWpUw6eeLji4nKB97VgADHekHjyCmb9oGDrashXMPawWG
1534	B62qphpEdBwSycpN67XFjcXSEY9j18chmttFTXYerhTPMX4JkXubWkd
1535	B62qjhiEXP45KEk8Fch4FnYJQ7UMMfiR3hq9ZeMUZ8ia3MbfEteSYDg
1536	B62qmPATxsWneeArMm7h2JU5og1vJafP9Qt5VFmMunnGZVR2DTC6ztM
1537	B62qipnm2igSVxVw6mqSdhU55kwwXDdE7mbh6FSiDj2zQFKhQ8iezwe
1538	B62qob1tGxx1BhychEzzah7yvdbRH3E7SNSTrEtkuSZzR2UBezMChg2
1539	B62qqhHs5hGXumEBYSAbKvC5edPKT6aUzf6XFRsANWq1XHwpJguYosx
1540	B62qs2JDc3nv4LPr4sW5oW3eAicxp4T6EQbGesAoJrcaoeEiynubHoU
1541	B62qq6ZYPG5JsjZnGJ3pADmRn6hU6qy13EhraTSymjSgyEDwoDR9Gd6
1542	B62qrr1gkgYvVfRb9JjstCcjDTKYYXFM61dD7oqFaEjc5VkFvL8zWgr
1543	B62qn7dN3hhEyqEYLG9Le1KwJpJfcJQXfiBoKiB7sZVrwYvT1NyRfDr
1544	B62qjSytpSK7aEauBprjXDSZwc9ai4YMv9tpmXLQK14Vy941YV36rMz
1545	B62qpZQ7xcNpv6zcY75D2y1V4K1DHXVpkbCJAYpPNHgutXAb6o5QSZE
1546	B62qiariqVhC5xzvUMsvtc3hxNBtsfb34anvrreAQA7t1647dZbyPjo
1547	B62qoG7mge74phWmvLdgMTrewb3Znpkvt3LYbtiKgvhN3v4kjVx1RPc
1548	B62qrW1cezZ24Dn7DMdb7WPVVpCcE4s9BhYDDz49rWyVeMinHb18bg8
1549	B62qoo7juS8X4i59TJ2iV4p7ogHqBwwuMC9VfsQFSNjZgZpNmGw58dJ
1550	B62qoKueAUixdjxSokbUN6LeKRZoXMHEhU6nD1zpZ5EDh7zNTaDQeNK
1551	B62qnxHx2ZXjZut1BnpCRiLinjQxH6yLgwGgB5VyuQYWdeum9p3kE3b
1552	B62qrE1TgV5jegA2rn32gi7FkHbFSvo2xRxKwhYykAiAsLy7ib7Uwnc
1553	B62qn1jcWzM2h1f2HjLku6hjS5dAJ4pgjRaV3PzEHBbPTNtqKafsdhR
1554	B62qjJ2eGwj1mmB6XThCV2m9JxUqJGXLqwyirxTbzBanzs2ThazD1Gy
1555	B62qrPbHUhxVqe17VwkzTyUmEsFwVry8geJEb7zfBVa8kocYAs2j4nn
1556	B62qoi7wVz5NDCYa37usdATKcvMVcbtXYLjn3KiELXSEsG7XcbifC3q
1557	B62qnFs1Hb4TQdDFMrm3LaS6e6dxfXPTXH3WpjyiQQxuRvVtBiZ2fx8
1558	B62qm2o16xqCCqV5vkfqYEHNNqFSsMx6VK835H8uszpd78bnsTbvQHV
1559	B62qpM6uZJgwBf6ahjkYNMD5aJEt3LBHe3wRkNHD5LoxR5EHPKV9zwN
1560	B62qrQBarKiVK11xP943pMQxnmNrfYpT7hskHLWdFXbx2K1E9wR1Vdy
1561	B62qrQiw9JhUumq457sMxicgQ94Z1WD9JChzJu19kBE8Szb5T8tcUAC
1562	B62qqEbM64qqDsLzefbkavB3RJWy3oZUbZ9HikqCKRBTvqbsbR53ogD
1563	B62qoySzFYHZ96RZFFc4CRYeh2gp5xF53XxLXJ3XFmnzBxXsd4KRikA
1564	B62qn9aR9hkH43oXtW7mMcvDqvCBwVguCf5QyN89sHmBVuDEkuEg6yE
1565	B62qqPJmQCXeRmjSj7jJPXvgshHVBfbeXmNW2uRBf7pwVsB7pzbcqFH
1566	B62qqaGu2Hz6122My8Ddxj5WPgQd1tVLmXXJioxa7Wm5m5VJPzoZdhc
1567	B62qrF464XvEDcs5yYa6FnZsz1RhW79HQCyvfQLME7w9NDuqrdAgfuD
1568	B62qqvDf19E357mwCfM6fHRhuBTaNcwnKCJbaNE3waGnQ8uNZZPU66g
1569	B62qmrsFZNeW2ReoHpTafy9hy1oNw12UuR1UdGJEUqTuFZ3LPVccDTA
1570	B62qjWrUQMud5mWVPSeMs9t41mrXdWFPfPA23a3nsEbGWBTEiapipqH
1571	B62qozyeUmdsCUP3kCJXNMDwCENUA6SA7ZtnGWiZbSWaB5yeuMVVJF2
1572	B62qrCz3ehCqi8Pn8y3vWC9zYEB9RKsidauv15DeZxhzkxL3bKeba5h
1573	B62qm3iPXvCBATaBTVt4NyWigBX45JvjGqK9PJj2TjdtdLaipUt1Byg
1574	B62qo3iHrCUfCtxQU9hcHT5kehJsQB32fE6JwMAadSMML8Cg4eTPBpe
1575	B62qjeR6fS4Z9dyaNt1UWPh8bHWm4euq5ksKnctfQdwucSzRGh9cFZV
1576	B62qqK6M9q1eE8MNnmeGytCUhgY3nq83hMxstjtcyqiEGuNMTvjNDHW
1577	B62qm4ueLWLDXXfKCuKXL72rwXtiLsWRAKGJXH7jEGPjjbzR41RqVun
1578	B62qpEMj7NwUbeWyyPrPUHtJDqJb1RkPxJtm6JxHrXUKDFMgJYp1zzT
1579	B62qn9vwCUbefEmPsj6g29df18TmAQ2bSthrRFGvWG1jKDEbi2wJT15
1580	B62qjmUyv9D4GQ35RFSDrXjMqgFYW4VtDkuv1q8TnxosPqxSJcbdvzG
1581	B62qipA4mZXjXaKHv6GSakqhjpoAa9wZnAKV5X4HyFyy6vz6aqCNYeD
1582	B62qqE5R5pJDUjPrKZMtTkPKUPL27kwNZ1sHkZaowxSLosZvLudt3kW
1583	B62qoahjAyUBNcXBn8HTb7Rk48sBzfZnjDa592MqjCnMXeWpFkGS6zJ
1584	B62qkXeeeerxc4YMtV8qBki2bTQc5KBZ5CCZk85xsjTBh2iEQ2PJmce
1585	B62qmPxwf3FTtb62toALY6k6q4HiCWJCUGP8xyxpDFsgwhFCnHBEQvp
1586	B62qpdKVxef96UTWaEPEbGQ7FruwCSbEckDHDGtpAQqxUfDmHR725AV
1587	B62qrJreRSCNusj6uYVanrFESuaaBu13Ri44djV6k7HkYNcarKEJBKu
1588	B62qqMU2Es9QPPYj7Vn54aJbbW5gibDZYu38LhGLGSjccSxJRQ5NkuK
1589	B62qkLn4YDsHjoiRus1G2HmUKUutGbQGTVEtRT6NKaB1RRMYCN2d6JM
1590	B62qnTahyoiqVSW9qbqiTBczA7n1wim9d7PYwGxWZP2s6mgwMn9AoGg
1591	B62qnR6HKx34NCyDkSeRcJ44KATjUCs4xmQYDbwTXPJPQ4J6ebfeQe4
1592	B62qjcPuh2BcHqKMFEsUAshFRVvDn2V9xVrrRpn9Szarx63NBmehJPP
1593	B62qo74q1yCcNhJ17iYrNEpTWEJwBPdDzs72hFDDwm4PDWVihC5jFbG
1594	B62qkoSio33qzxjsAuY4KVYmjw784KuyDSxbRL4d8UJaLXmdgVqb4N4
1595	B62qnzLZyeTiesV9EvUxUU2AHqyWfd7kAWEWL8QqJm5Uaadpmwafrj2
1596	B62qmeKQQvdH15JDyFWYhm8N6mpuV3tbZzqkZSGFsMZnbXNVqmsYvvg
1597	B62qnvzUAvwnAiK3eMVQooshDA5AmEF9jKRrUTt5cwbCvVFiF47vdqp
1598	B62qnAZCj1kbyDHpxo6Lm9yM2FqMj4ffJTQzJeiPhgkzpEw1S33caCZ
1599	B62qmQ5ufDZUTz8tm1GVQvmNrn4Don4hXPJ5GFMJpP8VEXkHJCZ9ySW
1600	B62qkHM9NT3nDefqUvSMe8qnfEfeXipqkzZrvoBXpfaC9m2BdYjWVJA
1601	B62qpXqPzauUXLnsAQFnYHMCiV9pRqG2wqbJ4pL936SVANHa66zkkQj
1602	B62qpkF1Yrd1uQNLpun7d8k12ggHEXjXHknLCKh6Hom7Q3Ba3oZg3nb
1603	B62qmpSNd5voNiVnyM4c1bcbRC53wdkEANwYZaA2iA5rgCv68XezSuG
1604	B62qmiJsasogL3iTj2HhSE5AyhN3y5x2GYuvccCBdT1xYB2bpuSHL2P
1605	B62qjqYBrf5erL4LHSapiuvcX9TMLCVqCuyzYYGC2sGZfKxt8tQ67Vz
1606	B62qpy6sXLwATHek6wjWKqmDukA7m62rtF1ChoTt1ZMT2po3a4hTW3R
1607	B62qnwWiVgFTCEvyo6buKUnexc4LQX1Sbuw87iwvanNmkPyP5zm43h5
1608	B62qrae3PEBj66KV2obWnzVxMjDCMuFWnyzxEzvLkQutaKPmWtfUPm3
1609	B62qktmhyar5294GEBpPfgYrSEBxkAcn52273bdR4CiGELoVpLtaC6c
1610	B62qoQjPL289fYLgcPzDmZ1Dv5kqNYANsicix6v6epSHXUW6H3XUTL9
1611	B62qk5RNZP2c4xbrefavDjRM9wLP63kFCVdd4TRKfmtKLXEimdDrKNX
1612	B62qrVGh6mx3DQBmXobnWidM265mxSD3aisVjR7c9KMyZV5FfXqywST
1613	B62qrJowiiRAYWQUrhyieAdFuDJgQ2MoyCqTzotP2ECRVptb63f7bG3
1614	B62qj8KB2fk59NkV4VuoTkVXHjw8VJzC3ybKrWo7zuDC9xTiWXPygEe
1615	B62qmqprUwxHxG6uGDQe48Xys9diJhunEqQNRuFC5a1KBUNsDaNADgj
1616	B62qkhfgERAi7TUjujZ8gdwSbA9TnJxvErjwfZTeftKmpdjJxWxGHGT
1617	B62qk2ujo9BoBxCs9BFQUsv3efaJDzbJeLs4YJdZMJzJoVj69ShVdKs
1618	B62qoWcd3dUzbjMHTdpjf5Us88x1otEoJmhSVRX7FXf1Dx1zT5Hp3ZC
1619	B62qpzciXjUdvgsKcstj1jKLnyPCtWFFuvtwr54xakf7tRucz3CgHB7
1620	B62qoeKm4p9J6Q3hYWzb82Yo5uP163MqooBX4ZWjp8FpX3N6Y81QgFc
1621	B62qkVjzzRRXe7FA2P6Dv5rJkxYT5u8QWYAfuU2U7b6yZpoRfgQhCSy
1622	B62qkJdU5HYtzLHfc5T8U9SompB4GBxA9Uhjy434qKHRQBbLhPJjWuc
1623	B62qrwBEB3tjGvjZNNr4h8N2iHGvcgRa6bb3V7Qs7Z15EZVWnyJBpXR
1624	B62qq3tqfdj19hqaVCozJFM2q9gT2WezQMaJMKD6wxyvK3fMpHiP9va
1625	B62qrBRnUXvdMr8eGLBsmdpvFnndinDZMowqoMUYRJnmGKpdJv7TMRj
1626	B62qnwfauXg2i7e1CYGdJjztyfdJ8CiESr37hzm5X5HJnYwp22rBpSD
1627	B62qjmhssErdKxMjXuXaABYjTnhWjzbtdm63XSpjNb9ddPNvtfJ2JbX
1628	B62qmQ4pFXU4tyNwdzMY7uCdrALptYp8SnthWJMqPPA3FgmxebY3H2P
1629	B62qnsWWJEU7U7XFNLtqH4bKZAMcPK9mr5CeohEuufkV1fT3wgNSV1T
1630	B62qqvZh85mfqj7mFhKfDnC1n6aCxw8Ey876Vw2z4E4tnCkRpcHTJ7b
1631	B62qn2Ne2JGRdbHXdfD8wkA6PTWuBjaxUDQ6QuPAmggrcYjTP3HwWkF
1632	B62qnbx3HVFsNCd6v7TJT16nxB1UEekBKektHy5WZ8GRotwTEqAtJsX
1633	B62qqjvE7v6Qrf1h7xtn4U57eMq8m7CPpkgwS3aCY8w9jQgnzAoPoUp
1634	B62qpGnZs3EZ8eYuxn8ANNwcexMhYqjjSLKBer8KhsviXGdEDwi63St
1635	B62qorXXHv971Kvnq91TkvWsRAvMCB8yszCX6yUhpyZseKcibSZSDSF
1636	B62qmnouVrbSqDevkjai8WsetJZSC1kR52vmz94WDRj724KyqYJ7MBJ
1637	B62qmTSi7ZMLJLGTNADvhg2NSL7roR2AxPW3JgrkY81nFB56AJGTcN8
1638	B62qknBg1mTvb9uXy9exbBsxs16BXgMQiJ5N73eEFXmWBLaRetqMvMb
1639	B62qpVUF5PXf7vh4eH8cZ3om3mp23bQJPDqwE2iB8BaE5ZUhaCJdU8L
1640	B62qr6owPPGkPVLVFcXnQHvijQxH4TAVqXhJAcMuKWvLXnHCtLZyxPZ
1641	B62qpLeuZDL7PxNsCqsJwWFPAmnixi5ay8Kz9NcNGBQU8jK19VpJQaY
1642	B62qotPF3i34VMSyp3A44ziyME2R7MRN2vH4W2Yen352MW3JW4G6hq9
1643	B62qrcFgyk8u1NPaTvw9zZE1RVYGAeURojHds8WMjEpzHakU7BefkMf
1644	B62qqUD5wTz7iVVrT2axj7tVY3kybSPZBJBDXRgZTPgJJHm5eD5aR1b
1645	B62qj3tjfzAhoLX9ymWvPsTZTK3Pm125SLSSGGfPrvhc3zbPr1D1A2y
1646	B62qp4Xg1zuAkTc1cyG8N2xQrujJaZ9uesm26Jy9sr2w65XUnNaGEEQ
1647	B62qm4QbSnmQWM3x7SUiQeWAjb6iiooWNd8iaxtDvsne7YP4nC8Nh7f
1648	B62qrHzjcZbYSsrcXVgGko7go1DzSEBfdQGPon5X4LEGExtNJZA4ECj
1649	B62qqJXzVcb63kE6zFEXJn2GsQ4DTjygTE3ymjYSsyHRt61qVoUBZyr
1650	B62qr7o47ANtvCpSzdVXXoweGkaZkwWnq2mZ6Heg7KQTCuShF4KeKFS
1651	B62qiwgNcH1uw76xgqJMb4V1nuD91qbxrQGWay96u9TBkgPb4HxRJeX
1652	B62qmpHMDeuGL1KAkneV1RTKMez2ZNcDUJKNAEZgweJna62xuJQ6Mqm
1653	B62qoDCpSv1cmWiXgYvDud8L4dk5oTwC9JkyXyz9b13j5uFKiEFjv9D
1654	B62qq6ceNHCu9mSBvczmHS5JzHC4zw5U9KLALuwZPemeksx82AEfQSr
1655	B62qim7EVe62u3wDsGzAZEMGMaEuwSXYWTCH1WsNvWFgfvz7ysggDxf
1656	B62qq3Lg31BG99W3DfpUNUr78UYhxUEEQdjSURViWhopsNHPUZy5CqA
1657	B62qmRG3THXszPjfJXDCk2MjDZqWLXMoVzyEWMPStEdfqhMe7GJaGxE
1658	B62qmBBEPcCpWqvMhParohskEjDttye1A7iSxwmMncXXgKkgjQ9PA7y
1659	B62qrQMvZrta9QjfQAmC9JsUjyUWDXX3h18nRt4FZm7wNgj9YPKwM5Z
1660	B62qj1EFvWbmmoUw2FH1AvUtRSP6av8MFYTiqsB7SQbHPtqNT2SWFEg
1661	B62qp8PCgNSzawdhooGXPQhULtZ4yhNzMb4UVSd3sTLz5tR8Btdtqn5
1662	B62qnWPnneWPobbir3JncBDVnj9dGvT1RA713xYVxJ9sBYgYHiu68Xh
1663	B62qrzoBfFuUxJg2YvcBkBnziVtAPziP5uAPcCPpQZgtjE4LTxXvVSJ
1664	B62qnr2iUdADcgeYKUVjjvXaPy4qXXz8gmYUYu2WbHA8ZaieWMo2r9s
1665	B62qoQjc9zF7TrVeLP4vUvYXfDoWGFPn5Q1jFjLDWwB6ocA1VXYyTPs
1666	B62qpUXyywHB2yRbgwEfmoUSh3KwN66W8a8QoXqpoTiHJkoQMcgJXbu
1667	B62qpzWppkJex4Hx7Y6rSq8yH9JMaGc8R1b3nkSjH3mk3aYKNyX6DKW
1668	B62qkQCXhzstenWTCwbGqRgdvivBQEE2WDNRWLRo4gAXcnkQKZ1FAta
1669	B62qqKoxyhPfHY9kw283dafk5jztbbKdH78eDXpNCyj69cmckC8KZqs
1670	B62qopE6unCuyENJR7qzj5NuJ8nMfj3dD214AVUpUeYbLyarawUvq8N
1671	B62qpMcYjgezccPk8NfaSto4jyV3uGU8R24D9uSShMoqr8JdpAv4RKo
1672	B62qq9CY1jVwTNjxbqUxNT4qhAy24woM1uzYA2HUo4QEGpkyUDXt3YF
1673	B62qoERu6rA6UUxk6yNYN9CfrvXwNB7tBF94TQucZNRkabQNiDJoMiR
1674	B62qjQ3k78nzaePyXhg298UEVnwbCeqQUcNwZRSR4VK1gVJ6mer6M8V
1675	B62qkVNThXvoXtZERUnkGYSoDbSDwnXntVyE8anpNSGLSQ7DejZMtMe
1676	B62qpFJeY8uiLwzhrmwFGthQS7yjZonyUACq32G4ULkZcRB9W3WVFgE
\.


--
-- Data for Name: snarked_ledger_hashes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.snarked_ledger_hashes (id, value) FROM stdin;
1	jx7buQVWFLsXTtzRgSxbYcT8EYLS8KCZbLrfDcJxMtyy4thw2Ee
\.


--
-- Data for Name: timing_info; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.timing_info (id, public_key_id, token, initial_balance, initial_minimum_balance, cliff_time, cliff_amount, vesting_period, vesting_increment) FROM stdin;
1	2	1	372093000000000	372093000000000	86400	372093000000000	1	0
2	3	1	230400000000000	230400000000000	86400	230400000000000	1	0
3	4	1	145418000000000	145418000000000	86400	145418000000000	1	0
4	5	1	148837200000000	148837200000000	86400	148837200000000	1	0
5	6	1	6697000000000	6697000000000	86400	6697000000000	1	0
6	7	1	32558000000000	32558000000000	86400	32558000000000	1	0
7	8	1	2326000000000	2326000000000	86400	2326000000000	1	0
8	9	1	10233000000000	10233000000000	86400	10233000000000	1	0
9	10	1	32558000000000	32558000000000	86400	32558000000000	1	0
10	11	1	32558000000000	32558000000000	86400	32558000000000	1	0
11	12	1	4651000000000	4651000000000	86400	4651000000000	1	0
12	13	1	2791000000000	2791000000000	86400	2791000000000	1	0
13	14	1	4651000000000	4651000000000	86400	4651000000000	1	0
14	15	1	4884000000000	4884000000000	86400	4884000000000	1	0
15	16	1	9767000000000	9767000000000	86400	9767000000000	1	0
16	17	1	9767000000000	9767000000000	86400	9767000000000	1	0
17	18	1	32558000000000	32558000000000	86400	32558000000000	1	0
18	19	1	4651000000000	4651000000000	86400	4651000000000	1	0
19	20	1	2326000000000	2326000000000	86400	2326000000000	1	0
20	21	1	26047000000000	26047000000000	86400	26047000000000	1	0
21	22	1	32558000000000	32558000000000	86400	32558000000000	1	0
22	23	1	22326000000000	22326000000000	86400	22326000000000	1	0
23	24	1	32558000000000	32558000000000	86400	32558000000000	1	0
24	25	1	930000000000	930000000000	86400	930000000000	1	0
25	26	1	9302000000000	9302000000000	86400	9302000000000	1	0
26	27	1	49460000000000	49460000000000	86400	49460000000000	1	0
27	28	1	10000000000000	10000000000000	86400	10000000000000	1	0
28	29	1	20000000000000	20000000000000	86400	20000000000000	1	0
29	30	1	7000000000000	7000000000000	86400	7000000000000	1	0
30	31	1	6000000000000	6000000000000	172800	1500000000000	1	8680556
31	32	1	1318605000000000	1318605000000000	86400	1318605000000000	1	0
32	33	1	73627000000000	73627000000000	86400	73627000000000	1	0
33	34	1	10400000000000	10400000000000	86400	10400000000000	1	0
34	35	1	66976000000000	66976000000000	86400	66976000000000	1	0
35	36	1	19200000000000	19200000000000	86400	19200000000000	1	0
36	37	1	30000000000000	30000000000000	86400	30000000000000	1	0
37	38	1	65328000000000	65328000000000	86400	65328000000000	1	0
38	39	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
39	40	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
40	41	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
41	42	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
42	43	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
43	44	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
44	45	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
45	46	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
46	47	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
47	48	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
48	49	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
49	50	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
50	51	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
51	52	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
52	53	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
53	54	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
54	55	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
55	56	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
56	57	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
57	58	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
58	59	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
59	60	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
60	61	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
61	62	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
62	63	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
63	64	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
64	65	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
65	66	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
66	67	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
67	68	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
68	69	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
69	70	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
70	71	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
71	72	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
72	73	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
73	74	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
74	75	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
75	76	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
76	77	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
77	78	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
78	79	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
79	80	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
80	81	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
81	82	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
82	83	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
83	84	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
84	85	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
85	86	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
86	87	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
87	88	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
88	89	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
89	90	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
90	91	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
91	92	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
92	93	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
93	94	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
94	95	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
95	96	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
96	97	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
97	98	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
98	99	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
99	100	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
100	101	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
101	102	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
102	103	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
103	104	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
104	105	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
105	106	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
106	107	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
107	108	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
108	109	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
109	110	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
110	111	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
111	112	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
112	113	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
113	114	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
114	115	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
115	116	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
116	117	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
117	118	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
118	119	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
119	120	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
120	121	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
121	122	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
122	123	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
123	124	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
124	125	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
125	126	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
126	127	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
127	128	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
128	129	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
129	130	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
130	131	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
131	132	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
132	133	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
133	134	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
134	135	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
135	136	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
136	137	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
137	138	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
138	139	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
139	140	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
140	141	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
141	142	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
142	143	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
143	144	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
144	145	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
145	146	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
146	147	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
147	148	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
148	149	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
149	150	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
150	151	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
151	152	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
152	153	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
153	154	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
154	155	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
155	156	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
156	157	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
157	158	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
158	159	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
159	160	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
160	161	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
161	162	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
162	163	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
163	164	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
164	165	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
165	166	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
166	167	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
167	168	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
168	169	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
169	170	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
170	171	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
171	172	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
172	173	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
173	174	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
174	175	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
175	176	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
176	177	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
177	178	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
178	179	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
179	180	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
180	181	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
181	182	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
182	183	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
183	184	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
184	185	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
185	186	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
186	187	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
187	188	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
188	189	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
189	190	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
190	191	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
191	192	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
192	193	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
193	194	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
194	195	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
195	196	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
196	197	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
197	198	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
198	199	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
199	200	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
200	201	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
201	202	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
202	203	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
203	204	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
204	205	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
205	206	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
206	207	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
207	208	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
208	209	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
209	210	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
210	211	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
211	212	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
212	213	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
213	214	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
214	215	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
215	216	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
216	217	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
217	218	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
218	219	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
219	220	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
220	221	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
221	222	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
222	223	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
223	224	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
224	225	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
225	226	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
226	227	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
227	228	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
228	229	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
229	230	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
230	231	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
231	232	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
232	233	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
233	234	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
234	235	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
235	236	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
236	237	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
237	238	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
238	239	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
239	240	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
240	241	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
241	242	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
242	243	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
243	244	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
244	245	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
245	246	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
246	247	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
247	248	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
248	249	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
249	250	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
250	251	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
251	252	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
252	253	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
253	254	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
254	255	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
255	256	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
256	257	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
257	258	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
258	259	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
259	260	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
260	261	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
261	262	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
262	263	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
263	264	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
264	265	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
265	266	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
266	267	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
267	268	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
268	269	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
269	270	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
270	271	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
271	272	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
272	273	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
273	274	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
274	275	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
275	276	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
276	277	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
277	278	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
278	279	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
279	280	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
280	281	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
281	282	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
282	283	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
283	284	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
284	285	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
285	286	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
286	287	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
287	288	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
288	289	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
289	290	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
290	291	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
291	292	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
292	293	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
293	294	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
294	295	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
295	296	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
296	297	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
297	298	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
298	299	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
299	300	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
300	301	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
301	302	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
302	303	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
303	304	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
304	305	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
305	306	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
306	307	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
307	308	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
308	309	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
309	310	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
310	311	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
311	312	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
312	313	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
313	314	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
314	315	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
315	316	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
316	317	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
317	318	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
318	319	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
319	320	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
320	321	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
321	322	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
322	323	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
323	324	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
324	325	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
325	326	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
326	327	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
327	328	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
328	329	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
329	330	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
330	331	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
331	332	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
332	333	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
333	334	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
334	335	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
335	336	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
336	337	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
337	338	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
338	339	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
339	340	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
340	341	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
341	342	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
342	343	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
343	344	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
344	345	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
345	346	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
346	347	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
347	348	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
348	349	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
349	350	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
350	351	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
351	352	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
352	353	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
353	354	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
354	355	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
355	356	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
356	357	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
357	358	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
358	359	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
359	360	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
360	361	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
361	362	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
362	363	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
363	364	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
364	365	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
365	366	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
366	367	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
367	368	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
368	369	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
369	370	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
370	371	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
371	372	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
372	373	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
373	374	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
374	375	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
375	376	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
376	377	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
377	378	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
378	379	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
379	380	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
380	381	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
381	382	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
382	383	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
383	384	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
384	385	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
385	386	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
386	387	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
387	388	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
388	389	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
389	390	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
390	391	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
391	392	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
392	393	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
393	394	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
394	395	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
395	396	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
396	397	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
397	398	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
398	399	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
399	400	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
400	401	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
401	402	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
402	403	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
403	404	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
404	405	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
405	406	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
406	407	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
407	408	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
408	409	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
409	410	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
410	411	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
411	412	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
412	413	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
413	414	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
414	415	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
415	416	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
416	417	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
417	418	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
418	419	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
419	420	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
420	421	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
421	422	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
422	423	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
423	424	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
424	425	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
425	426	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
426	427	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
427	428	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
428	429	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
429	430	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
430	431	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
431	432	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
432	433	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
433	434	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
434	435	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
435	436	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
436	437	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
437	438	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
438	439	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
439	440	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
440	441	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
441	442	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
442	443	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
443	444	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
444	445	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
445	446	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
446	447	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
447	448	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
448	449	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
449	450	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
450	451	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
451	452	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
452	453	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
453	454	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
454	455	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
455	456	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
456	457	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
457	458	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
458	459	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
459	460	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
460	461	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
461	462	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
462	463	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
463	464	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
464	465	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
465	466	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
466	467	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
467	468	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
468	469	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
469	470	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
470	471	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
471	472	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
472	473	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
473	474	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
474	475	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
475	476	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
476	477	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
477	478	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
478	479	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
479	480	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
480	481	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
481	482	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
482	483	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
483	484	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
484	485	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
485	486	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
486	487	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
487	488	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
488	489	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
489	490	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
490	491	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
491	492	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
492	493	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
493	494	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
494	495	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
495	496	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
496	497	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
497	498	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
498	499	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
499	500	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
500	501	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
501	502	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
502	503	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
503	504	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
504	505	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
505	506	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
506	507	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
507	508	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
508	509	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
509	510	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
510	511	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
511	512	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
512	513	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
513	514	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
514	515	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
515	516	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
516	517	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
517	518	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
518	519	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
519	520	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
520	521	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
521	522	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
522	523	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
523	524	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
524	525	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
525	526	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
526	527	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
527	528	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
528	529	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
529	530	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
530	531	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
531	532	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
532	533	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
533	534	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
534	535	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
535	536	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
536	537	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
537	538	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
538	539	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
539	540	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
540	541	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
541	542	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
542	543	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
543	544	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
544	545	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
545	546	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
546	547	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
547	548	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
548	549	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
549	550	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
550	551	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
551	552	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
552	553	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
553	554	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
554	555	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
555	556	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
556	557	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
557	558	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
558	559	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
559	560	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
560	561	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
561	562	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
562	563	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
563	564	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
564	565	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
565	566	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
566	567	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
567	568	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
568	569	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
569	570	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
570	571	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
571	572	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
572	573	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
573	574	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
574	575	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
575	576	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
576	577	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
577	578	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
578	579	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
579	580	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
580	581	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
581	582	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
582	583	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
583	584	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
584	585	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
585	586	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
586	587	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
587	588	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
588	589	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
589	590	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
590	591	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
591	592	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
592	593	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
593	594	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
594	595	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
595	596	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
596	597	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
597	598	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
598	599	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
599	600	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
600	601	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
601	602	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
602	603	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
603	604	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
604	605	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
605	606	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
606	607	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
607	608	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
608	609	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
609	610	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
610	611	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
611	612	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
612	613	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
613	614	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
614	615	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
615	616	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
616	617	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
617	618	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
618	619	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
619	620	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
620	621	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
621	622	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
622	623	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
623	624	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
624	625	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
625	626	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
626	627	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
627	628	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
628	629	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
629	630	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
630	631	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
631	632	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
632	633	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
633	634	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
634	635	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
635	636	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
636	637	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
637	638	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
638	639	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
639	640	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
640	641	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
641	642	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
642	643	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
643	644	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
644	645	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
645	646	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
646	647	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
647	648	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
648	649	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
649	650	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
650	651	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
651	652	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
652	653	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
653	654	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
654	655	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
655	656	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
656	657	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
657	658	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
658	659	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
659	660	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
660	661	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
661	662	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
662	663	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
663	664	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
664	665	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
665	666	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
666	667	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
667	668	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
668	669	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
669	670	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
670	671	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
671	672	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
672	673	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
673	674	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
674	675	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
675	676	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
676	677	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
677	678	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
678	679	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
679	680	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
680	681	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
681	682	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
682	683	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
683	684	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
684	685	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
685	686	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
686	687	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
687	688	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
688	689	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
689	690	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
690	691	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
691	692	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
692	693	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
693	694	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
694	695	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
695	696	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
696	697	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
697	698	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
698	699	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
699	700	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
700	701	1	66000000000000	66000000000000	172800	16500000000000	1	95486111
701	702	1	85000000000000	85000000000000	86400	85000000000000	1	0
702	703	1	44000000000000	44000000000000	86400	44000000000000	1	0
703	704	1	17000000000000	17000000000000	86400	17000000000000	1	0
704	705	1	10000000000000	10000000000000	86400	10000000000000	1	0
705	706	1	10000000000000	10000000000000	86400	10000000000000	1	0
706	707	1	10000000000000	10000000000000	86400	10000000000000	1	0
707	708	1	9000000000000	9000000000000	86400	9000000000000	1	0
708	709	1	6000000000000	6000000000000	86400	6000000000000	1	0
709	710	1	10000000000000	10000000000000	86400	10000000000000	1	0
710	711	1	5000000000000	5000000000000	86400	5000000000000	1	0
711	712	1	3000000000000	3000000000000	86400	3000000000000	1	0
712	713	1	6000000000000	6000000000000	86400	6000000000000	1	0
713	714	1	42000000000000	42000000000000	86400	42000000000000	1	0
714	715	1	2000000000000	2000000000000	86400	2000000000000	1	0
715	716	1	2000000000000	2000000000000	86400	2000000000000	1	0
716	717	1	3000000000000	3000000000000	86400	3000000000000	1	0
717	718	1	2000000000000	2000000000000	86400	2000000000000	1	0
718	719	1	2000000000000	2000000000000	86400	2000000000000	1	0
719	720	1	2000000000000	2000000000000	86400	2000000000000	1	0
720	721	1	2000000000000	2000000000000	86400	2000000000000	1	0
721	722	1	2000000000000	2000000000000	86400	2000000000000	1	0
722	723	1	2000000000000	2000000000000	86400	2000000000000	1	0
723	724	1	3000000000000	3000000000000	86400	3000000000000	1	0
724	725	1	20000000000000	20000000000000	86400	20000000000000	1	0
725	726	1	15000000000000	15000000000000	86400	15000000000000	1	0
726	727	1	6000000000000	6000000000000	86400	6000000000000	1	0
727	728	1	5000000000000	5000000000000	86400	5000000000000	1	0
728	729	1	5000000000000	5000000000000	86400	5000000000000	1	0
729	730	1	5000000000000	5000000000000	86400	5000000000000	1	0
730	731	1	5000000000000	5000000000000	86400	5000000000000	1	0
731	732	1	2000000000000	2000000000000	86400	2000000000000	1	0
732	733	1	2000000000000	2000000000000	86400	2000000000000	1	0
733	734	1	2000000000000	2000000000000	86400	2000000000000	1	0
734	735	1	2000000000000	2000000000000	86400	2000000000000	1	0
735	736	1	3000000000000	3000000000000	86400	3000000000000	1	0
736	737	1	2000000000000	2000000000000	86400	2000000000000	1	0
737	738	1	3000000000000	3000000000000	86400	3000000000000	1	0
738	739	1	20000000000000	20000000000000	86400	20000000000000	1	0
739	740	1	10000000000000	10000000000000	86400	10000000000000	1	0
740	741	1	5000000000000	5000000000000	86400	5000000000000	1	0
741	742	1	5000000000000	5000000000000	86400	5000000000000	1	0
742	743	1	5000000000000	5000000000000	86400	5000000000000	1	0
743	744	1	2000000000000	2000000000000	86400	2000000000000	1	0
744	745	1	2000000000000	2000000000000	86400	2000000000000	1	0
745	746	1	2000000000000	2000000000000	86400	2000000000000	1	0
746	747	1	2000000000000	2000000000000	86400	2000000000000	1	0
747	748	1	2000000000000	2000000000000	86400	2000000000000	1	0
748	749	1	2000000000000	2000000000000	86400	2000000000000	1	0
749	750	1	1000000000000	1000000000000	86400	1000000000000	1	0
750	751	1	1000000000000	1000000000000	86400	1000000000000	1	0
751	752	1	1000000000000	1000000000000	86400	1000000000000	1	0
752	753	1	1000000000000	1000000000000	86400	1000000000000	1	0
753	754	1	1000000000000	1000000000000	86400	1000000000000	1	0
754	755	1	1000000000000	1000000000000	86400	1000000000000	1	0
755	756	1	1000000000000	1000000000000	86400	1000000000000	1	0
756	757	1	1000000000000	1000000000000	86400	1000000000000	1	0
757	758	1	1000000000000	1000000000000	86400	1000000000000	1	0
758	759	1	1000000000000	1000000000000	86400	1000000000000	1	0
759	760	1	1000000000000	1000000000000	86400	1000000000000	1	0
760	761	1	1000000000000	1000000000000	86400	1000000000000	1	0
761	762	1	1000000000000	1000000000000	86400	1000000000000	1	0
762	763	1	1000000000000	1000000000000	86400	1000000000000	1	0
763	764	1	1000000000000	1000000000000	86400	1000000000000	1	0
764	765	1	1000000000000	1000000000000	86400	1000000000000	1	0
765	766	1	1000000000000	1000000000000	86400	1000000000000	1	0
766	767	1	1000000000000	1000000000000	86400	1000000000000	1	0
767	768	1	1000000000000	1000000000000	86400	1000000000000	1	0
768	769	1	1000000000000	1000000000000	86400	1000000000000	1	0
769	770	1	1000000000000	1000000000000	86400	1000000000000	1	0
770	771	1	1000000000000	1000000000000	86400	1000000000000	1	0
771	772	1	1000000000000	1000000000000	86400	1000000000000	1	0
772	773	1	1000000000000	1000000000000	86400	1000000000000	1	0
773	774	1	1000000000000	1000000000000	86400	1000000000000	1	0
774	775	1	1000000000000	1000000000000	86400	1000000000000	1	0
775	776	1	1388891712964990	1388891712964990	36480	1172841890948210	1	32150271133
776	777	1	15277795509265100	15277795509265100	43200	0	1	70730534765
777	778	1	1388891712964990	1388891712964990	36480	1172841890948210	1	32150271133
778	779	1	15277795509265100	15277795509265100	43200	0	1	70730534765
779	780	1	27778216210792	27778216210792	36480	23457160355780	1	643014264
780	781	1	305560111648051	305560111648051	43200	0	1	1414630147
781	782	1	222221235183807	222221235183807	36480	187653487488548	1	5144010074
782	783	1	2444431453699720	2444431453699720	43200	0	1	11316812286
783	784	1	29861135198413	29861135198413	36480	25216069723104	1	691229981
784	785	1	328472200515873	328472200515873	43200	0	1	1520704632
785	786	1	222221235183807	222221235183807	36480	187653487488548	1	5144010074
786	787	1	2444431453699720	2444431453699720	43200	0	1	11316812286
787	788	1	55556432421584	55556432421584	36480	46914320711560	1	1286028528
788	789	1	611120223296101	611120223296101	43200	0	1	2829260293
789	790	1	238889081587303	238889081587303	36480	201728557784834	1	5529839852
790	791	1	2627777604126980	2627777604126980	43200	0	1	12165637056
791	792	1	55556432421584	55556432421584	36480	46914320711560	1	1286028528
792	793	1	611120223296101	611120223296101	43200	0	1	2829260293
793	794	1	1361806307764150	1361806307764150	36480	1149969771000840	1	31523294161
794	795	1	14979856312075500	14979856312075500	43200	0	1	69351186630
795	796	1	55556593519694	55556593519694	36480	46914456749964	1	1286032257
796	797	1	611121995373765	611121995373765	43200	0	1	2829268497
797	798	1	277777828703501	277777828703501	36480	234567944238512	1	6430042331
798	799	1	3055553449073490	3055553449073490	43200	0	1	14146080783
799	800	1	13887863656181	13887863656181	36480	11727529309664	1	321478325
800	801	1	152766366894607	152766366894607	43200	0	1	707251699
801	802	1	13890433103666	13890433103666	36480	11729699065318	1	321537803
802	803	1	152794630792275	152794630792275	43200	0	1	707382550
803	804	1	16665388062455	16665388062455	36480	14072994363851	1	385772872
804	805	1	183319108699404	183319108699404	43200	0	1	848699577
805	806	1	111110295403134	111110295403134	36480	93826471673758	1	2571997579
806	807	1	1222212182776490	1222212182776490	43200	0	1	5658389735
807	808	1	27778296759847	27778296759847	36480	23457228374982	1	643016129
808	809	1	305560997686882	305560997686882	43200	0	1	1414634249
809	810	1	59722270396826	59722270396826	36480	50432139446208	1	1382459963
810	811	1	656944401031746	656944401031746	43200	0	1	3041409264
811	812	1	107500086714286	107500086714286	36480	90777851003175	1	2488427933
812	813	1	1182499921857140	1182499921857140	43200	0	1	5474536675
813	814	1	500001633334793	500001633334793	36480	422223601482714	1	11574111883
814	815	1	5500013166670880	5500013166670880	43200	0	1	25463023920
815	816	1	2027778894047020	2027778894047020	36480	1712346621639700	1	46939326251
816	817	1	22305548367855400	22305548367855400	43200	0	1	103266427629
817	818	1	55554024072209	55554024072209	36480	46912286994310	1	1285972779
818	819	1	611093731476097	611093731476097	43200	0	1	2829137646
819	820	1	55554024072209	55554024072209	36480	46912286994310	1	1285972779
820	821	1	611093731476097	611093731476097	43200	0	1	2829137646
821	822	1	27778216210792	27778216210792	36480	23457160355780	1	643014264
822	823	1	305560111648051	305560111648051	43200	0	1	1414630147
823	824	1	1725001865185760	1725001865185760	36480	1456668241712420	1	39930598731
824	825	1	18975003957038700	18975003957038700	43200	0	1	87847240542
825	826	1	55556432421584	55556432421584	36480	46914320711560	1	1286028528
826	827	1	611120223296101	611120223296101	43200	0	1	2829260293
827	828	1	83332079192342	83332079192342	36480	70369311317978	1	1928983315
828	829	1	916652071128441	916652071128441	43200	0	1	4243759589
829	830	1	333333455649436	333333455649436	36480	281481584770635	1	7716052214
830	831	1	3666664812145190	3666664812145190	43200	0	1	16975300056
831	832	1	55556432421584	55556432421584	36480	46914320711560	1	1286028528
832	833	1	611120223296101	611120223296101	43200	0	1	2829260293
833	834	1	400013579074275	400013579074275	36480	400013579074275	1	0
834	835	1	479991629337776	479991629337776	36480	479991629337776	1	0
835	836	1	3199985304837430	3199985304837430	36480	3199985304837430	1	0
836	837	1	1200009905283630	1200009905283630	36480	1200009905283630	1	0
837	838	1	1599992652418710	1599992652418710	36480	1599992652418710	1	0
838	839	1	599989536672220	599989536672220	36480	599989536672220	1	0
839	840	1	2399988978628070	2399988978628070	36480	2399988978628070	1	0
840	841	1	1200009905283630	1200009905283630	36480	1200009905283630	1	0
841	842	1	83287416647298	83287416647298	86400	4627082404291	1	321324895
842	843	1	83287416647298	83287416647298	86400	4627082404291	1	321324895
843	844	1	155277777741667	155277777741667	86400	8626550109105	1	599065472
844	845	1	155277777741667	155277777741667	86400	8626550109105	1	599065472
845	846	1	573333333200000	573333333200000	86400	31851877325926	1	2211934052
846	847	1	573333333200000	573333333200000	86400	31851877325926	1	2211934052
847	848	1	185138888845833	185138888845833	86400	10285502053164	1	714270371
848	849	1	185138888845833	185138888845833	86400	10285502053164	1	714270371
849	850	1	1149647999732640	1149647999732640	86400	63869384413947	1	4435370161
850	851	1	1149647999732640	1149647999732640	86400	63869384413947	1	4435370161
851	852	1	2227041666148750	2227041666148750	86400	123724635987893	1	8591981332
852	853	1	2227041666148750	2227041666148750	86400	123724635987893	1	8591981332
853	854	1	245567177026225	245567177026225	86400	13642631859998	1	947404188
854	855	1	245567177026225	245567177026225	86400	13642631859998	1	947404188
855	856	1	129895833303125	129895833303125	86400	7216440956655	1	501141309
856	857	1	129895833303125	129895833303125	86400	7216440956655	1	501141309
857	858	1	327530402701608	327530402701608	86400	18196148040329	1	1263620321
858	859	1	327530402701608	327530402701608	86400	18196148040329	1	1263620321
859	860	1	144537333299720	144537333299720	86400	8029858273866	1	557628574
860	861	1	144537333299720	144537333299720	86400	8029858273866	1	557628574
861	862	1	452395833228125	452395833228125	86400	25133121952488	1	1745354213
862	863	1	452395833228125	452395833228125	86400	25133121952488	1	1745354213
863	864	1	95775333311060	95775333311060	86400	5320856107296	1	369503583
864	865	1	95775333311060	95775333311060	86400	5320856107296	1	369503583
865	866	1	397152777685417	397152777685417	86400	22064060855980	1	1532225150
866	867	1	397152777685417	397152777685417	86400	22064060855980	1	1532225150
867	868	1	2418750000000000	2418750000000000	86400	2418750000000000	1	0
868	869	1	2418750000000000	2418750000000000	86400	2418750000000000	1	0
869	870	1	258666499939845	258666499939845	86400	14370372604058	1	997941697
870	871	1	258666499939845	258666499939845	86400	14370372604058	1	997941697
871	872	1	109739583307813	109739583307813	86400	6096648394416	1	423378002
872	873	1	109739583307813	109739583307813	86400	6096648394416	1	423378002
873	874	1	2418750000000000	2418750000000000	86400	2418750000000000	1	0
874	875	1	2418750000000000	2418750000000000	86400	2418750000000000	1	0
875	876	1	212013888839583	212013888839583	86400	11778558802816	1	817954780
876	877	1	212013888839583	212013888839583	86400	11778558802816	1	817954780
877	878	1	203053166619445	203053166619445	86400	11280740503443	1	783384094
878	879	1	203053166619445	203053166619445	86400	11280740503443	1	783384094
879	880	1	134374999968750	134374999968750	86400	7465283748264	1	518422043
880	881	1	134374999968750	134374999968750	86400	7465283748264	1	518422043
881	882	1	582291666531250	582291666531250	86400	32349562909144	1	2246495521
882	883	1	582291666531250	582291666531250	86400	32349562909144	1	2246495521
883	884	1	89583333312500	89583333312500	86400	4976855832176	1	345614696
884	885	1	89583333312500	89583333312500	86400	4976855832176	1	345614696
885	886	1	63454861096354	63454861096354	86400	3525272881125	1	244810409
886	887	1	63454861096354	63454861096354	86400	3525272881125	1	244810409
887	888	1	267369520771154	267369520771154	86400	14853874148154	1	1031518164
888	889	1	267369520771154	267369520771154	86400	14853874148154	1	1031518164
889	890	1	224442381892249	224442381892249	86400	12469031191453	1	865904210
890	891	1	224442381892249	224442381892249	86400	12469031191453	1	865904210
891	892	1	492708333218750	492708333218750	86400	27372707076968	1	1900880826
892	893	1	492708333218750	492708333218750	86400	27372707076968	1	1900880826
893	894	1	306822916595313	306822916595313	86400	17045731225203	1	1183730332
894	895	1	306822916595313	306822916595313	86400	17045731225203	1	1183730332
895	896	1	143333333300000	143333333300000	86400	7962969331481	1	552983513
896	897	1	143333333300000	143333333300000	86400	7962969331481	1	552983513
897	898	1	64994499984885	64994499984885	86400	3610808443360	1	250750374
898	899	1	64994499984885	64994499984885	86400	3610808443360	1	250750374
899	900	1	38742999990990	38742999990990	86400	2152390610299	1	149471444
900	901	1	38742999990990	38742999990990	86400	2152390610299	1	149471444
901	902	1	116458333306250	116458333306250	86400	6469912581829	1	449299104
902	903	1	116458333306250	116458333306250	86400	6469912581829	1	449299104
903	904	1	114218749973438	114218749973438	86400	6345491186024	1	440658737
904	905	1	114218749973438	114218749973438	86400	6345491186024	1	440658737
905	906	1	418802083235938	418802083235938	86400	23266801015423	1	1615748702
906	907	1	418802083235938	418802083235938	86400	23266801015423	1	1615748702
907	908	1	502777775000000	1000000000	691200	1000000000	1	0
908	909	1	502777775000000	1000000000	691200	1000000000	1	0
909	910	1	502777775000000	1000000000	691200	1000000000	1	0
910	911	1	502777775000000	1000000000	691200	1000000000	1	0
911	912	1	502777775000000	1000000000	691200	1000000000	1	0
912	913	1	502777775000000	1000000000	691200	1000000000	1	0
913	914	1	502777775000000	1000000000	691200	1000000000	1	0
914	915	1	502777775000000	1000000000	691200	1000000000	1	0
915	916	1	502777775000000	1000000000	691200	1000000000	1	0
916	917	1	502777775000000	1000000000	691200	1000000000	1	0
917	918	1	502777775000000	1000000000	691200	1000000000	1	0
918	919	1	502777775000000	1000000000	691200	1000000000	1	0
919	920	1	502777775000000	1000000000	691200	1000000000	1	0
920	921	1	502777775000000	1000000000	691200	1000000000	1	0
921	922	1	502777775000000	1000000000	691200	1000000000	1	0
922	923	1	502777775000000	1000000000	691200	1000000000	1	0
923	924	1	502777775000000	1000000000	691200	1000000000	1	0
924	925	1	502777775000000	1000000000	691200	1000000000	1	0
925	926	1	502777775000000	1000000000	691200	1000000000	1	0
926	927	1	502777775000000	1000000000	691200	1000000000	1	0
927	928	1	502777775000000	1000000000	691200	1000000000	1	0
928	929	1	502777775000000	1000000000	691200	1000000000	1	0
929	930	1	502777775000000	1000000000	691200	1000000000	1	0
930	931	1	502777775000000	1000000000	691200	1000000000	1	0
931	932	1	502777775000000	1000000000	691200	1000000000	1	0
932	933	1	502777775000000	1000000000	691200	1000000000	1	0
933	934	1	502777775000000	1000000000	691200	1000000000	1	0
934	935	1	502777775000000	1000000000	691200	1000000000	1	0
935	936	1	502777775000000	1000000000	691200	1000000000	1	0
936	937	1	502777775000000	1000000000	691200	1000000000	1	0
937	938	1	502777775000000	1000000000	691200	1000000000	1	0
938	939	1	502777775000000	1000000000	691200	1000000000	1	0
939	940	1	502777775000000	1000000000	691200	1000000000	1	0
940	941	1	502777775000000	1000000000	691200	1000000000	1	0
941	942	1	502777775000000	1000000000	691200	1000000000	1	0
942	943	1	502777775000000	1000000000	691200	1000000000	1	0
943	944	1	502777775000000	1000000000	691200	1000000000	1	0
944	945	1	502777775000000	1000000000	691200	1000000000	1	0
945	946	1	502777775000000	1000000000	691200	1000000000	1	0
946	947	1	502777775000000	1000000000	691200	1000000000	1	0
947	948	1	502777775000000	1000000000	691200	1000000000	1	0
948	949	1	502777775000000	1000000000	691200	1000000000	1	0
949	950	1	502777775000000	1000000000	691200	1000000000	1	0
950	951	1	502777775000000	1000000000	691200	1000000000	1	0
951	952	1	502777775000000	1000000000	691200	1000000000	1	0
952	953	1	502777775000000	1000000000	691200	1000000000	1	0
953	954	1	502777775000000	1000000000	691200	1000000000	1	0
954	955	1	502777775000000	1000000000	691200	1000000000	1	0
955	956	1	502777775000000	1000000000	691200	1000000000	1	0
956	957	1	502777775000000	1000000000	691200	1000000000	1	0
957	958	1	502777775000000	1000000000	691200	1000000000	1	0
958	959	1	502777775000000	1000000000	691200	1000000000	1	0
959	960	1	502777775000000	1000000000	691200	1000000000	1	0
960	961	1	502777775000000	1000000000	691200	1000000000	1	0
961	962	1	502777775000000	1000000000	691200	1000000000	1	0
962	963	1	502777775000000	1000000000	691200	1000000000	1	0
963	964	1	502777775000000	1000000000	691200	1000000000	1	0
964	965	1	502777775000000	1000000000	691200	1000000000	1	0
965	966	1	502777775000000	1000000000	691200	1000000000	1	0
966	967	1	502777775000000	1000000000	691200	1000000000	1	0
967	968	1	502777775000000	1000000000	691200	1000000000	1	0
968	969	1	502777775000000	1000000000	691200	1000000000	1	0
969	970	1	502777775000000	1000000000	691200	1000000000	1	0
970	971	1	502777775000000	1000000000	691200	1000000000	1	0
971	972	1	502777775000000	1000000000	691200	1000000000	1	0
972	973	1	502777775000000	1000000000	691200	1000000000	1	0
973	974	1	502777775000000	1000000000	691200	1000000000	1	0
974	975	1	502777775000000	1000000000	691200	1000000000	1	0
975	976	1	502777775000000	1000000000	691200	1000000000	1	0
976	977	1	502777775000000	1000000000	691200	1000000000	1	0
977	978	1	502777775000000	1000000000	691200	1000000000	1	0
978	979	1	502777775000000	1000000000	691200	1000000000	1	0
979	980	1	502777775000000	1000000000	691200	1000000000	1	0
980	981	1	502777775000000	1000000000	691200	1000000000	1	0
981	982	1	502777775000000	1000000000	691200	1000000000	1	0
982	983	1	502777775000000	1000000000	691200	1000000000	1	0
983	984	1	502777775000000	1000000000	691200	1000000000	1	0
984	985	1	502777775000000	1000000000	691200	1000000000	1	0
985	986	1	502777775000000	1000000000	691200	1000000000	1	0
986	987	1	502777775000000	1000000000	691200	1000000000	1	0
987	988	1	502777775000000	1000000000	691200	1000000000	1	0
988	989	1	502777775000000	1000000000	691200	1000000000	1	0
989	990	1	502777775000000	1000000000	691200	1000000000	1	0
990	991	1	502777775000000	1000000000	691200	1000000000	1	0
991	992	1	502777775000000	1000000000	691200	1000000000	1	0
992	993	1	502777775000000	1000000000	691200	1000000000	1	0
993	994	1	502777775000000	1000000000	691200	1000000000	1	0
994	995	1	502777775000000	1000000000	691200	1000000000	1	0
995	996	1	502777775000000	1000000000	691200	1000000000	1	0
996	997	1	502777775000000	1000000000	691200	1000000000	1	0
997	998	1	502777775000000	1000000000	691200	1000000000	1	0
998	999	1	502777775000000	1000000000	691200	1000000000	1	0
999	1000	1	502777775000000	1000000000	691200	1000000000	1	0
1000	1001	1	502777775000000	1000000000	691200	1000000000	1	0
1001	1002	1	502777775000000	1000000000	691200	1000000000	1	0
1002	1003	1	502777775000000	1000000000	691200	1000000000	1	0
1003	1004	1	502777775000000	1000000000	691200	1000000000	1	0
1004	1005	1	502777775000000	1000000000	691200	1000000000	1	0
1005	1006	1	502777775000000	1000000000	691200	1000000000	1	0
1006	1007	1	502777775000000	1000000000	691200	1000000000	1	0
1007	1008	1	502777775000000	1000000000	691200	1000000000	1	0
1008	1009	1	502777775000000	1000000000	691200	1000000000	1	0
1009	1010	1	502777775000000	1000000000	691200	1000000000	1	0
1010	1011	1	502777775000000	1000000000	691200	1000000000	1	0
1011	1012	1	502777775000000	1000000000	691200	1000000000	1	0
1012	1013	1	502777775000000	1000000000	691200	1000000000	1	0
1013	1014	1	502777775000000	1000000000	691200	1000000000	1	0
1014	1015	1	502777775000000	1000000000	691200	1000000000	1	0
1015	1016	1	502777775000000	1000000000	691200	1000000000	1	0
1016	1017	1	502777775000000	1000000000	691200	1000000000	1	0
1017	1018	1	502777775000000	1000000000	691200	1000000000	1	0
1018	1019	1	502777775000000	1000000000	691200	1000000000	1	0
1019	1020	1	502777775000000	1000000000	691200	1000000000	1	0
1020	1021	1	502777775000000	1000000000	691200	1000000000	1	0
1021	1022	1	502777775000000	1000000000	691200	1000000000	1	0
1022	1023	1	502777775000000	1000000000	691200	1000000000	1	0
1023	1024	1	502777775000000	1000000000	691200	1000000000	1	0
1024	1025	1	502777775000000	1000000000	691200	1000000000	1	0
1025	1026	1	502777775000000	1000000000	691200	1000000000	1	0
1026	1027	1	502777775000000	1000000000	691200	1000000000	1	0
1027	1028	1	900973465000000	1000000000	691200	1000000000	1	0
1028	1029	1	900973465000000	1000000000	691200	1000000000	1	0
1029	1030	1	900973465000000	1000000000	691200	1000000000	1	0
1030	1031	1	900973465000000	1000000000	691200	1000000000	1	0
1031	1032	1	900973465000000	1000000000	691200	1000000000	1	0
1032	1033	1	900973465000000	1000000000	691200	1000000000	1	0
1033	1034	1	900973465000000	1000000000	691200	1000000000	1	0
1034	1035	1	900973465000000	1000000000	691200	1000000000	1	0
1035	1036	1	900973465000000	1000000000	691200	1000000000	1	0
1036	1037	1	900973465000000	1000000000	691200	1000000000	1	0
1037	1038	1	900973465000000	1000000000	691200	1000000000	1	0
1038	1039	1	900973465000000	1000000000	691200	1000000000	1	0
1039	1040	1	900973465000000	1000000000	691200	1000000000	1	0
1040	1041	1	900973465000000	1000000000	691200	1000000000	1	0
1041	1042	1	900973465000000	1000000000	691200	1000000000	1	0
1042	1043	1	900973465000000	1000000000	691200	1000000000	1	0
1043	1044	1	900973465000000	1000000000	691200	1000000000	1	0
1044	1045	1	900973465000000	1000000000	691200	1000000000	1	0
1045	1046	1	900973465000000	1000000000	691200	1000000000	1	0
1046	1047	1	900973465000000	1000000000	691200	1000000000	1	0
1047	1048	1	900973465000000	1000000000	691200	1000000000	1	0
1048	1049	1	900973465000000	1000000000	691200	1000000000	1	0
1049	1050	1	900973465000000	1000000000	691200	1000000000	1	0
1050	1051	1	900973465000000	1000000000	691200	1000000000	1	0
1051	1052	1	900973465000000	1000000000	691200	1000000000	1	0
1052	1053	1	900973465000000	1000000000	691200	1000000000	1	0
1053	1054	1	900973465000000	1000000000	691200	1000000000	1	0
1054	1055	1	900973465000000	1000000000	691200	1000000000	1	0
1055	1056	1	900973465000000	1000000000	691200	1000000000	1	0
1056	1057	1	900973465000000	1000000000	691200	1000000000	1	0
1057	1058	1	900973465000000	1000000000	691200	1000000000	1	0
1058	1059	1	900973465000000	1000000000	691200	1000000000	1	0
1059	1060	1	900973465000000	1000000000	691200	1000000000	1	0
1060	1061	1	900973465000000	1000000000	691200	1000000000	1	0
1061	1062	1	900973465000000	1000000000	691200	1000000000	1	0
1062	1063	1	900973465000000	1000000000	691200	1000000000	1	0
1063	1064	1	900973465000000	1000000000	691200	1000000000	1	0
1064	1065	1	900973465000000	1000000000	691200	1000000000	1	0
1065	1066	1	900973465000000	1000000000	691200	1000000000	1	0
1066	1067	1	900973465000000	1000000000	691200	1000000000	1	0
1067	1068	1	900973465000000	1000000000	691200	1000000000	1	0
1068	1069	1	900973465000000	1000000000	691200	1000000000	1	0
1069	1070	1	900973465000000	1000000000	691200	1000000000	1	0
1070	1071	1	900973465000000	1000000000	691200	1000000000	1	0
1071	1072	1	900973465000000	1000000000	691200	1000000000	1	0
1072	1073	1	900973465000000	1000000000	691200	1000000000	1	0
1073	1074	1	900973465000000	1000000000	691200	1000000000	1	0
1074	1075	1	900973465000000	1000000000	691200	1000000000	1	0
1075	1076	1	900973465000000	1000000000	691200	1000000000	1	0
1076	1077	1	900973465000000	1000000000	691200	1000000000	1	0
1077	1078	1	900973465000000	1000000000	691200	1000000000	1	0
1078	1079	1	900973465000000	1000000000	691200	1000000000	1	0
1079	1080	1	900973465000000	1000000000	691200	1000000000	1	0
1080	1081	1	900973465000000	1000000000	691200	1000000000	1	0
1081	1082	1	900973465000000	1000000000	691200	1000000000	1	0
1082	1083	1	900973465000000	1000000000	691200	1000000000	1	0
1083	1084	1	900973465000000	1000000000	691200	1000000000	1	0
1084	1085	1	900973465000000	1000000000	691200	1000000000	1	0
1085	1086	1	900973465000000	1000000000	691200	1000000000	1	0
1086	1087	1	900973465000000	1000000000	691200	1000000000	1	0
1087	1088	1	900973465000000	1000000000	691200	1000000000	1	0
1088	1089	1	900973465000000	1000000000	691200	1000000000	1	0
1089	1090	1	900973465000000	1000000000	691200	1000000000	1	0
1090	1091	1	900973465000000	1000000000	691200	1000000000	1	0
1091	1092	1	900973465000000	1000000000	691200	1000000000	1	0
1092	1093	1	900973465000000	1000000000	691200	1000000000	1	0
1093	1094	1	900973465000000	1000000000	691200	1000000000	1	0
1094	1095	1	900973465000000	1000000000	691200	1000000000	1	0
1095	1096	1	900973465000000	1000000000	691200	1000000000	1	0
1096	1097	1	900973465000000	1000000000	691200	1000000000	1	0
1097	1098	1	900973465000000	1000000000	691200	1000000000	1	0
1098	1099	1	900973465000000	1000000000	691200	1000000000	1	0
1099	1100	1	900973465000000	1000000000	691200	1000000000	1	0
1100	1101	1	900973465000000	1000000000	691200	1000000000	1	0
1101	1102	1	900973465000000	1000000000	691200	1000000000	1	0
1102	1103	1	900973465000000	1000000000	691200	1000000000	1	0
1103	1104	1	900973465000000	1000000000	691200	1000000000	1	0
1104	1105	1	900973465000000	1000000000	691200	1000000000	1	0
1105	1106	1	900973465000000	1000000000	691200	1000000000	1	0
1106	1107	1	900973465000000	1000000000	691200	1000000000	1	0
1107	1108	1	900973465000000	1000000000	691200	1000000000	1	0
1108	1109	1	900973465000000	1000000000	691200	1000000000	1	0
1109	1110	1	900973465000000	1000000000	691200	1000000000	1	0
1110	1111	1	900973465000000	1000000000	691200	1000000000	1	0
1111	1112	1	900973465000000	1000000000	691200	1000000000	1	0
1112	1113	1	900973465000000	1000000000	691200	1000000000	1	0
1113	1114	1	900973465000000	1000000000	691200	1000000000	1	0
1114	1115	1	900973465000000	1000000000	691200	1000000000	1	0
1115	1116	1	900973465000000	1000000000	691200	1000000000	1	0
1116	1117	1	900973465000000	1000000000	691200	1000000000	1	0
1117	1118	1	900973465000000	1000000000	691200	1000000000	1	0
1118	1119	1	900973465000000	1000000000	691200	1000000000	1	0
1119	1120	1	900973465000000	1000000000	691200	1000000000	1	0
1120	1121	1	900973465000000	1000000000	691200	1000000000	1	0
1121	1122	1	900973465000000	1000000000	691200	1000000000	1	0
1122	1123	1	900973465000000	1000000000	691200	1000000000	1	0
1123	1124	1	900973465000000	1000000000	691200	1000000000	1	0
1124	1125	1	900973465000000	1000000000	691200	1000000000	1	0
1125	1126	1	900973465000000	1000000000	691200	1000000000	1	0
1126	1127	1	900973465000000	1000000000	691200	1000000000	1	0
1127	1128	1	900973465000000	1000000000	691200	1000000000	1	0
1128	1129	1	900973465000000	1000000000	691200	1000000000	1	0
1129	1130	1	900973465000000	1000000000	691200	1000000000	1	0
1130	1131	1	900973465000000	1000000000	691200	1000000000	1	0
1131	1132	1	900973465000000	1000000000	691200	1000000000	1	0
1132	1133	1	900973465000000	1000000000	691200	1000000000	1	0
1133	1134	1	900973465000000	1000000000	691200	1000000000	1	0
1134	1135	1	900973465000000	1000000000	691200	1000000000	1	0
1135	1136	1	900973465000000	1000000000	691200	1000000000	1	0
1136	1137	1	900973465000000	1000000000	691200	1000000000	1	0
1137	1138	1	900973465000000	1000000000	691200	1000000000	1	0
1138	1139	1	900973465000000	1000000000	691200	1000000000	1	0
1139	1140	1	900973465000000	1000000000	691200	1000000000	1	0
1140	1141	1	900973465000000	1000000000	691200	1000000000	1	0
1141	1142	1	900973465000000	1000000000	691200	1000000000	1	0
1142	1143	1	900973465000000	1000000000	691200	1000000000	1	0
1143	1144	1	900973465000000	1000000000	691200	1000000000	1	0
1144	1145	1	900973465000000	1000000000	691200	1000000000	1	0
1145	1146	1	900973465000000	1000000000	691200	1000000000	1	0
1146	1147	1	900973465000000	1000000000	691200	1000000000	1	0
1147	1148	1	607904750000000	1000000000	691200	1000000000	1	0
1148	1149	1	607904750000000	1000000000	691200	1000000000	1	0
1149	1150	1	607904750000000	1000000000	691200	1000000000	1	0
1150	1151	1	607904750000000	1000000000	691200	1000000000	1	0
1151	1152	1	607904750000000	1000000000	691200	1000000000	1	0
1152	1153	1	607904750000000	1000000000	691200	1000000000	1	0
1153	1154	1	607904750000000	1000000000	691200	1000000000	1	0
1154	1155	1	607904750000000	1000000000	691200	1000000000	1	0
1155	1156	1	607904750000000	1000000000	691200	1000000000	1	0
1156	1157	1	607904750000000	1000000000	691200	1000000000	1	0
1157	1158	1	607904750000000	1000000000	691200	1000000000	1	0
1158	1159	1	607904750000000	1000000000	691200	1000000000	1	0
1159	1160	1	607904750000000	1000000000	691200	1000000000	1	0
1160	1161	1	607904750000000	1000000000	691200	1000000000	1	0
1161	1162	1	607904750000000	1000000000	691200	1000000000	1	0
1162	1163	1	607904750000000	1000000000	691200	1000000000	1	0
1163	1164	1	607904750000000	1000000000	691200	1000000000	1	0
1164	1165	1	607904750000000	1000000000	691200	1000000000	1	0
1165	1166	1	607904750000000	1000000000	691200	1000000000	1	0
1166	1167	1	607904750000000	1000000000	691200	1000000000	1	0
1167	1168	1	607904750000000	1000000000	691200	1000000000	1	0
1168	1169	1	607904750000000	1000000000	691200	1000000000	1	0
1169	1170	1	607904750000000	1000000000	691200	1000000000	1	0
1170	1171	1	607904750000000	1000000000	691200	1000000000	1	0
1171	1172	1	607904750000000	1000000000	691200	1000000000	1	0
1172	1173	1	607904750000000	1000000000	691200	1000000000	1	0
1173	1174	1	607904750000000	1000000000	691200	1000000000	1	0
1174	1175	1	607904750000000	1000000000	691200	1000000000	1	0
1175	1176	1	607904750000000	1000000000	691200	1000000000	1	0
1176	1177	1	607904750000000	1000000000	691200	1000000000	1	0
1177	1178	1	607904750000000	1000000000	691200	1000000000	1	0
1178	1179	1	607904750000000	1000000000	691200	1000000000	1	0
1179	1180	1	607904750000000	1000000000	691200	1000000000	1	0
1180	1181	1	607904750000000	1000000000	691200	1000000000	1	0
1181	1182	1	607904750000000	1000000000	691200	1000000000	1	0
1182	1183	1	607904750000000	1000000000	691200	1000000000	1	0
1183	1184	1	607904750000000	1000000000	691200	1000000000	1	0
1184	1185	1	607904750000000	1000000000	691200	1000000000	1	0
1185	1186	1	607904750000000	1000000000	691200	1000000000	1	0
1186	1187	1	607904750000000	1000000000	691200	1000000000	1	0
1187	1188	1	607904750000000	1000000000	691200	1000000000	1	0
1188	1189	1	607904750000000	1000000000	691200	1000000000	1	0
1189	1190	1	607904750000000	1000000000	691200	1000000000	1	0
1190	1191	1	607904750000000	1000000000	691200	1000000000	1	0
1191	1192	1	607904750000000	1000000000	691200	1000000000	1	0
1192	1193	1	607904750000000	1000000000	691200	1000000000	1	0
1193	1194	1	607904750000000	1000000000	691200	1000000000	1	0
1194	1195	1	607904750000000	1000000000	691200	1000000000	1	0
1195	1196	1	607904750000000	1000000000	691200	1000000000	1	0
1196	1197	1	607904750000000	1000000000	691200	1000000000	1	0
1197	1198	1	607904750000000	1000000000	691200	1000000000	1	0
1198	1199	1	607904750000000	1000000000	691200	1000000000	1	0
1199	1200	1	607904750000000	1000000000	691200	1000000000	1	0
1200	1201	1	607904750000000	1000000000	691200	1000000000	1	0
1201	1202	1	607904750000000	1000000000	691200	1000000000	1	0
1202	1203	1	607904750000000	1000000000	691200	1000000000	1	0
1203	1204	1	607904750000000	1000000000	691200	1000000000	1	0
1204	1205	1	607904750000000	1000000000	691200	1000000000	1	0
1205	1206	1	607904750000000	1000000000	691200	1000000000	1	0
1206	1207	1	607904750000000	1000000000	691200	1000000000	1	0
1207	1208	1	607904750000000	1000000000	691200	1000000000	1	0
1208	1209	1	607904750000000	1000000000	691200	1000000000	1	0
1209	1210	1	607904750000000	1000000000	691200	1000000000	1	0
1210	1211	1	607904750000000	1000000000	691200	1000000000	1	0
1211	1212	1	607904750000000	1000000000	691200	1000000000	1	0
1212	1213	1	607904750000000	1000000000	691200	1000000000	1	0
1213	1214	1	607904750000000	1000000000	691200	1000000000	1	0
1214	1215	1	607904750000000	1000000000	691200	1000000000	1	0
1215	1216	1	607904750000000	1000000000	691200	1000000000	1	0
1216	1217	1	607904750000000	1000000000	691200	1000000000	1	0
1217	1218	1	607904750000000	1000000000	691200	1000000000	1	0
1218	1219	1	607904750000000	1000000000	691200	1000000000	1	0
1219	1220	1	607904750000000	1000000000	691200	1000000000	1	0
1220	1221	1	607904750000000	1000000000	691200	1000000000	1	0
1221	1222	1	607904750000000	1000000000	691200	1000000000	1	0
1222	1223	1	607904750000000	1000000000	691200	1000000000	1	0
1223	1224	1	607904750000000	1000000000	691200	1000000000	1	0
1224	1225	1	607904750000000	1000000000	691200	1000000000	1	0
1225	1226	1	607904750000000	1000000000	691200	1000000000	1	0
1226	1227	1	607904750000000	1000000000	691200	1000000000	1	0
1227	1228	1	607904750000000	1000000000	691200	1000000000	1	0
1228	1229	1	607904750000000	1000000000	691200	1000000000	1	0
1229	1230	1	607904750000000	1000000000	691200	1000000000	1	0
1230	1231	1	607904750000000	1000000000	691200	1000000000	1	0
1231	1232	1	607904750000000	1000000000	691200	1000000000	1	0
1232	1233	1	607904750000000	1000000000	691200	1000000000	1	0
1233	1234	1	607904750000000	1000000000	691200	1000000000	1	0
1234	1235	1	607904750000000	1000000000	691200	1000000000	1	0
1235	1236	1	607904750000000	1000000000	691200	1000000000	1	0
1236	1237	1	607904750000000	1000000000	691200	1000000000	1	0
1237	1238	1	607904750000000	1000000000	691200	1000000000	1	0
1238	1239	1	607904750000000	1000000000	691200	1000000000	1	0
1239	1240	1	607904750000000	1000000000	691200	1000000000	1	0
1240	1241	1	607904750000000	1000000000	691200	1000000000	1	0
1241	1242	1	607904750000000	1000000000	691200	1000000000	1	0
1242	1243	1	607904750000000	1000000000	691200	1000000000	1	0
1243	1244	1	607904750000000	1000000000	691200	1000000000	1	0
1244	1245	1	607904750000000	1000000000	691200	1000000000	1	0
1245	1246	1	607904750000000	1000000000	691200	1000000000	1	0
1246	1247	1	607904750000000	1000000000	691200	1000000000	1	0
1247	1248	1	607904750000000	1000000000	691200	1000000000	1	0
1248	1249	1	607904750000000	1000000000	691200	1000000000	1	0
1249	1250	1	607904750000000	1000000000	691200	1000000000	1	0
1250	1251	1	607904750000000	1000000000	691200	1000000000	1	0
1251	1252	1	607904750000000	1000000000	691200	1000000000	1	0
1252	1253	1	607904750000000	1000000000	691200	1000000000	1	0
1253	1254	1	607904750000000	1000000000	691200	1000000000	1	0
1254	1255	1	607904750000000	1000000000	691200	1000000000	1	0
1255	1256	1	607904750000000	1000000000	691200	1000000000	1	0
1256	1257	1	607904750000000	1000000000	691200	1000000000	1	0
1257	1258	1	607904750000000	1000000000	691200	1000000000	1	0
1258	1259	1	607904750000000	1000000000	691200	1000000000	1	0
1259	1260	1	607904750000000	1000000000	691200	1000000000	1	0
1260	1261	1	607904750000000	1000000000	691200	1000000000	1	0
1261	1262	1	607904750000000	1000000000	691200	1000000000	1	0
1262	1263	1	607904750000000	1000000000	691200	1000000000	1	0
1263	1264	1	607904750000000	1000000000	691200	1000000000	1	0
1264	1265	1	607904750000000	1000000000	691200	1000000000	1	0
1265	1266	1	607904750000000	1000000000	691200	1000000000	1	0
1266	1267	1	606464750000000	1000000000	691200	1000000000	1	0
1267	1268	1	93600000000000	1000000000	691200	1000000000	1	0
1268	1269	1	1000000000000	1000000000	86400	1000000000	1	0
1269	1270	1	0	0	0	0	0	0
1270	1271	1	0	0	0	0	0	0
1271	1272	1	1333326000000000	1000000000	259200	1000000000	1	0
1272	1273	1	11666659000000000	1000000000	259200	1000000000	1	0
1273	1274	1	1693980637751650	1000000000	345600	1000000000	1	0
1274	1275	1	1693980637751650	1000000000	345600	1000000000	1	0
1275	1276	1	1693980637751650	1000000000	345600	1000000000	1	0
1276	1277	1	1693980637751650	1000000000	345600	1000000000	1	0
1277	1278	1	1693980637751650	1000000000	345600	1000000000	1	0
1278	1279	1	1693980637751650	1000000000	345600	1000000000	1	0
1279	1280	1	1693980637751650	1000000000	345600	1000000000	1	0
1280	1281	1	1693980637751650	1000000000	345600	1000000000	1	0
1281	1282	1	1693980637751650	1000000000	345600	1000000000	1	0
1282	1283	1	1693980637751650	1000000000	345600	1000000000	1	0
1283	1284	1	1693980637751650	1000000000	345600	1000000000	1	0
1284	1285	1	1693980637751650	1000000000	345600	1000000000	1	0
1285	1286	1	1693980637751650	1000000000	345600	1000000000	1	0
1286	1287	1	1693980637751650	1000000000	345600	1000000000	1	0
1287	1288	1	1693980637751650	1000000000	345600	1000000000	1	0
1288	1289	1	1693980637751650	1000000000	345600	1000000000	1	0
1289	1290	1	1693980637751650	1000000000	345600	1000000000	1	0
1290	1291	1	1693980637751650	1000000000	345600	1000000000	1	0
1291	1292	1	1693980637751650	1000000000	345600	1000000000	1	0
1292	1293	1	1693980637751650	1000000000	345600	1000000000	1	0
1293	1294	1	1693980637751650	1000000000	345600	1000000000	1	0
1294	1295	1	1693980637751650	1000000000	345600	1000000000	1	0
1295	1296	1	1693980637751650	1000000000	345600	1000000000	1	0
1296	1297	1	1693980637751650	1000000000	345600	1000000000	1	0
1297	1298	1	1693980637751650	1000000000	345600	1000000000	1	0
1298	1299	1	1693980637751650	1000000000	345600	1000000000	1	0
1299	1300	1	1693980637751650	1000000000	345600	1000000000	1	0
1300	1301	1	1693980637751650	1000000000	345600	1000000000	1	0
1301	1302	1	1693980637751650	1000000000	345600	1000000000	1	0
1302	1303	1	1693980637751650	1000000000	345600	1000000000	1	0
1303	1304	1	1693980637751650	1000000000	345600	1000000000	1	0
1304	1305	1	1693980637751650	1000000000	345600	1000000000	1	0
1305	1306	1	1693980637751650	1000000000	345600	1000000000	1	0
1306	1307	1	1693980637751650	1000000000	345600	1000000000	1	0
1307	1308	1	1693980637751650	1000000000	345600	1000000000	1	0
1308	1309	1	1693980637751650	1000000000	345600	1000000000	1	0
1309	1310	1	1693980637751650	1000000000	345600	1000000000	1	0
1310	1311	1	1693980637751650	1000000000	345600	1000000000	1	0
1311	1312	1	1693980637751650	1000000000	345600	1000000000	1	0
1312	1313	1	1693980637751650	1000000000	345600	1000000000	1	0
1313	1314	1	1693980637751650	1000000000	345600	1000000000	1	0
1314	1315	1	1693980637751650	1000000000	345600	1000000000	1	0
1315	1316	1	1693980637751650	1000000000	345600	1000000000	1	0
1316	1317	1	1693980637751650	1000000000	345600	1000000000	1	0
1317	1318	1	1693980637751650	1000000000	345600	1000000000	1	0
1318	1319	1	1693980637751650	1000000000	345600	1000000000	1	0
1319	1320	1	1693980637751650	1000000000	345600	1000000000	1	0
1320	1321	1	1693980637751650	1000000000	345600	1000000000	1	0
1321	1322	1	1693980637751650	1000000000	345600	1000000000	1	0
1322	1323	1	1693980637751650	1000000000	345600	1000000000	1	0
1323	1324	1	1693980637751650	1000000000	345600	1000000000	1	0
1324	1325	1	1693980637751650	1000000000	345600	1000000000	1	0
1325	1326	1	1693980637751650	1000000000	345600	1000000000	1	0
1326	1327	1	1693980637751650	1000000000	345600	1000000000	1	0
1327	1328	1	1693980637751650	1000000000	345600	1000000000	1	0
1328	1329	1	1693980637751650	1000000000	345600	1000000000	1	0
1329	1330	1	1693980637751650	1000000000	345600	1000000000	1	0
1330	1331	1	1693980637751650	1000000000	345600	1000000000	1	0
1331	1332	1	1693980637751650	1000000000	345600	1000000000	1	0
1332	1333	1	1693980637751650	1000000000	345600	1000000000	1	0
1333	1334	1	1693980637751650	1000000000	345600	1000000000	1	0
1334	1335	1	1693980637751650	1000000000	345600	1000000000	1	0
1335	1336	1	1693980637751650	1000000000	345600	1000000000	1	0
1336	1337	1	1693980637751650	1000000000	345600	1000000000	1	0
1337	1338	1	1693980637751650	1000000000	345600	1000000000	1	0
1338	1339	1	1693980637751650	1000000000	345600	1000000000	1	0
1339	1340	1	1693980637751650	1000000000	345600	1000000000	1	0
1340	1341	1	1693980637751650	1000000000	345600	1000000000	1	0
1341	1342	1	1693980637751650	1000000000	345600	1000000000	1	0
1342	1343	1	1693980637751650	1000000000	345600	1000000000	1	0
1343	1344	1	1693980637751650	1000000000	345600	1000000000	1	0
1344	1345	1	1693980637751650	1000000000	345600	1000000000	1	0
1345	1346	1	1693980637751650	1000000000	345600	1000000000	1	0
1346	1347	1	1693980637751650	1000000000	345600	1000000000	1	0
1347	1348	1	1693980637751650	1000000000	345600	1000000000	1	0
1348	1349	1	1693980637751650	1000000000	345600	1000000000	1	0
1349	1350	1	1693980637751650	1000000000	345600	1000000000	1	0
1350	1351	1	1693980637751650	1000000000	345600	1000000000	1	0
1351	1352	1	1693980637751650	1000000000	345600	1000000000	1	0
1352	1353	1	1693980637751650	1000000000	345600	1000000000	1	0
1353	1354	1	1693980637751650	1000000000	345600	1000000000	1	0
1354	1355	1	1693980637751650	1000000000	345600	1000000000	1	0
1355	1356	1	1693980637751650	1000000000	345600	1000000000	1	0
1356	1357	1	1693980637751650	1000000000	345600	1000000000	1	0
1357	1358	1	1693980637751650	1000000000	345600	1000000000	1	0
1358	1359	1	1693980637751650	1000000000	345600	1000000000	1	0
1359	1360	1	1693980637751650	1000000000	345600	1000000000	1	0
1360	1361	1	1693980637751650	1000000000	345600	1000000000	1	0
1361	1362	1	1693980637751650	1000000000	345600	1000000000	1	0
1362	1363	1	1693980637751650	1000000000	345600	1000000000	1	0
1363	1364	1	1693980637751650	1000000000	345600	1000000000	1	0
1364	1365	1	1693980637751650	1000000000	345600	1000000000	1	0
1365	1366	1	1693980637751650	1000000000	345600	1000000000	1	0
1366	1367	1	1693980637751650	1000000000	345600	1000000000	1	0
1367	1368	1	1693980637751650	1000000000	345600	1000000000	1	0
1368	1369	1	1693980637751650	1000000000	345600	1000000000	1	0
1369	1370	1	1693980637751650	1000000000	345600	1000000000	1	0
1370	1371	1	1693980637751650	1000000000	345600	1000000000	1	0
1371	1372	1	1693980637751650	1000000000	345600	1000000000	1	0
1372	1373	1	1693980637751650	1000000000	345600	1000000000	1	0
1373	1374	1	1693980637751650	1000000000	345600	1000000000	1	0
1374	1375	1	1693980637751650	1000000000	345600	1000000000	1	0
1375	1376	1	1693980637751650	1000000000	345600	1000000000	1	0
1376	1377	1	1693980637751650	1000000000	345600	1000000000	1	0
1377	1378	1	1693980637751650	1000000000	345600	1000000000	1	0
1378	1379	1	1693980637751650	1000000000	345600	1000000000	1	0
1379	1380	1	1693980637751650	1000000000	345600	1000000000	1	0
1380	1381	1	1693980637751650	1000000000	345600	1000000000	1	0
1381	1382	1	1693980637751650	1000000000	345600	1000000000	1	0
1382	1383	1	1693980637751650	1000000000	345600	1000000000	1	0
1383	1384	1	1693980637751650	1000000000	345600	1000000000	1	0
1384	1385	1	1693980637751650	1000000000	345600	1000000000	1	0
1385	1386	1	1693980637751650	1000000000	345600	1000000000	1	0
1386	1387	1	1693980637751650	1000000000	345600	1000000000	1	0
1387	1388	1	1693980637751650	1000000000	345600	1000000000	1	0
1388	1389	1	1693980637751650	1000000000	345600	1000000000	1	0
1389	1390	1	1693980637751650	1000000000	345600	1000000000	1	0
1390	1391	1	1693980637751650	1000000000	345600	1000000000	1	0
1391	1392	1	1693980637751650	1000000000	345600	1000000000	1	0
1392	1393	1	1693980637751650	1000000000	345600	1000000000	1	0
1393	1394	1	75000000000000000	0	0	0	0	0
1394	1395	1	0	0	0	0	0	0
1395	1396	1	57617370302858700	1000000000	345600	1000000000	1	0
1396	1397	1	0	0	0	0	0	0
1397	1398	1	1440000000000	1000000000	345600	1000000000	1	0
1398	1399	1	0	0	0	0	0	0
1399	1400	1	0	0	0	0	0	0
1400	1401	1	0	0	0	0	0	0
1401	1402	1	0	0	0	0	0	0
1402	1403	1	0	0	0	0	0	0
1403	1404	1	0	0	0	0	0	0
1404	1405	1	0	0	0	0	0	0
1405	1406	1	0	0	0	0	0	0
1406	1407	1	0	0	0	0	0	0
1407	1408	1	0	0	0	0	0	0
1408	1409	1	0	0	0	0	0	0
1409	1410	1	0	0	0	0	0	0
1410	1411	1	0	0	0	0	0	0
1411	1412	1	0	0	0	0	0	0
1412	1413	1	0	0	0	0	0	0
1413	1414	1	0	0	0	0	0	0
1414	1415	1	0	0	0	0	0	0
1415	1416	1	0	0	0	0	0	0
1416	1417	1	0	0	0	0	0	0
1417	1418	1	0	0	0	0	0	0
1418	1419	1	0	0	0	0	0	0
1419	1420	1	0	0	0	0	0	0
1420	1421	1	0	0	0	0	0	0
1421	1422	1	0	0	0	0	0	0
1422	1423	1	0	0	0	0	0	0
1423	1424	1	0	0	0	0	0	0
1424	1425	1	0	0	0	0	0	0
1425	1426	1	0	0	0	0	0	0
1426	1427	1	0	0	0	0	0	0
1427	1428	1	0	0	0	0	0	0
1428	1429	1	0	0	0	0	0	0
1429	1430	1	0	0	0	0	0	0
1430	1431	1	0	0	0	0	0	0
1431	1432	1	0	0	0	0	0	0
1432	1433	1	0	0	0	0	0	0
1433	1434	1	0	0	0	0	0	0
1434	1435	1	0	0	0	0	0	0
1435	1436	1	0	0	0	0	0	0
1436	1437	1	0	0	0	0	0	0
1437	1438	1	0	0	0	0	0	0
1438	1439	1	0	0	0	0	0	0
1439	1440	1	0	0	0	0	0	0
1440	1441	1	0	0	0	0	0	0
1441	1442	1	0	0	0	0	0	0
1442	1443	1	0	0	0	0	0	0
1443	1444	1	0	0	0	0	0	0
1444	1445	1	0	0	0	0	0	0
1445	1446	1	0	0	0	0	0	0
1446	1447	1	0	0	0	0	0	0
1447	1448	1	0	0	0	0	0	0
1448	1449	1	0	0	0	0	0	0
1449	1450	1	0	0	0	0	0	0
1450	1451	1	0	0	0	0	0	0
1451	1452	1	0	0	0	0	0	0
1452	1453	1	0	0	0	0	0	0
1453	1454	1	0	0	0	0	0	0
1454	1455	1	0	0	0	0	0	0
1455	1456	1	0	0	0	0	0	0
1456	1457	1	0	0	0	0	0	0
1457	1458	1	0	0	0	0	0	0
1458	1459	1	0	0	0	0	0	0
1459	1460	1	0	0	0	0	0	0
1460	1461	1	0	0	0	0	0	0
1461	1462	1	0	0	0	0	0	0
1462	1463	1	0	0	0	0	0	0
1463	1464	1	0	0	0	0	0	0
1464	1465	1	0	0	0	0	0	0
1465	1466	1	0	0	0	0	0	0
1466	1467	1	0	0	0	0	0	0
1467	1468	1	0	0	0	0	0	0
1468	1469	1	0	0	0	0	0	0
1469	1470	1	0	0	0	0	0	0
1470	1471	1	0	0	0	0	0	0
1471	1472	1	0	0	0	0	0	0
1472	1473	1	0	0	0	0	0	0
1473	1474	1	0	0	0	0	0	0
1474	1475	1	0	0	0	0	0	0
1475	1476	1	0	0	0	0	0	0
1476	1477	1	0	0	0	0	0	0
1477	1478	1	0	0	0	0	0	0
1478	1479	1	0	0	0	0	0	0
1479	1480	1	0	0	0	0	0	0
1480	1481	1	0	0	0	0	0	0
1481	1482	1	0	0	0	0	0	0
1482	1483	1	0	0	0	0	0	0
1483	1484	1	0	0	0	0	0	0
1484	1485	1	0	0	0	0	0	0
1485	1486	1	0	0	0	0	0	0
1486	1487	1	0	0	0	0	0	0
1487	1488	1	0	0	0	0	0	0
1488	1489	1	0	0	0	0	0	0
1489	1490	1	0	0	0	0	0	0
1490	1491	1	0	0	0	0	0	0
1491	1492	1	0	0	0	0	0	0
1492	1493	1	0	0	0	0	0	0
1493	1494	1	0	0	0	0	0	0
1494	1495	1	0	0	0	0	0	0
1495	1496	1	0	0	0	0	0	0
1496	1497	1	0	0	0	0	0	0
1497	1498	1	0	0	0	0	0	0
1498	1499	1	0	0	0	0	0	0
1499	1500	1	0	0	0	0	0	0
1500	1501	1	0	0	0	0	0	0
1501	1502	1	0	0	0	0	0	0
1502	1503	1	0	0	0	0	0	0
1503	1504	1	0	0	0	0	0	0
1504	1505	1	0	0	0	0	0	0
1505	1506	1	0	0	0	0	0	0
1506	1507	1	0	0	0	0	0	0
1507	1508	1	0	0	0	0	0	0
1508	1509	1	0	0	0	0	0	0
1509	1510	1	0	0	0	0	0	0
1510	1511	1	0	0	0	0	0	0
1511	1512	1	0	0	0	0	0	0
1512	1513	1	0	0	0	0	0	0
1513	1514	1	0	0	0	0	0	0
1514	1515	1	0	0	0	0	0	0
1515	1516	1	0	0	0	0	0	0
1516	1517	1	0	0	0	0	0	0
1517	1518	1	0	0	0	0	0	0
1518	1519	1	0	0	0	0	0	0
1519	1520	1	0	0	0	0	0	0
1520	1521	1	0	0	0	0	0	0
1521	1522	1	0	0	0	0	0	0
1522	1523	1	0	0	0	0	0	0
1523	1524	1	0	0	0	0	0	0
1524	1525	1	0	0	0	0	0	0
1525	1526	1	0	0	0	0	0	0
1526	1527	1	0	0	0	0	0	0
1527	1528	1	0	0	0	0	0	0
1528	1529	1	0	0	0	0	0	0
1529	1530	1	0	0	0	0	0	0
1530	1531	1	0	0	0	0	0	0
1531	1532	1	0	0	0	0	0	0
1532	1533	1	0	0	0	0	0	0
1533	1534	1	0	0	0	0	0	0
1534	1535	1	0	0	0	0	0	0
1535	1536	1	0	0	0	0	0	0
1536	1537	1	0	0	0	0	0	0
1537	1538	1	0	0	0	0	0	0
1538	1539	1	0	0	0	0	0	0
1539	1540	1	0	0	0	0	0	0
1540	1541	1	0	0	0	0	0	0
1541	1542	1	0	0	0	0	0	0
1542	1543	1	0	0	0	0	0	0
1543	1544	1	0	0	0	0	0	0
1544	1545	1	0	0	0	0	0	0
1545	1546	1	0	0	0	0	0	0
1546	1547	1	0	0	0	0	0	0
1547	1548	1	0	0	0	0	0	0
1548	1549	1	0	0	0	0	0	0
1549	1550	1	0	0	0	0	0	0
1550	1551	1	0	0	0	0	0	0
1551	1552	1	0	0	0	0	0	0
1552	1553	1	0	0	0	0	0	0
1553	1554	1	0	0	0	0	0	0
1554	1555	1	0	0	0	0	0	0
1555	1556	1	0	0	0	0	0	0
1556	1557	1	0	0	0	0	0	0
1557	1558	1	0	0	0	0	0	0
1558	1559	1	0	0	0	0	0	0
1559	1560	1	0	0	0	0	0	0
1560	1561	1	0	0	0	0	0	0
1561	1562	1	0	0	0	0	0	0
1562	1563	1	0	0	0	0	0	0
1563	1564	1	0	0	0	0	0	0
1564	1565	1	0	0	0	0	0	0
1565	1566	1	0	0	0	0	0	0
1566	1567	1	0	0	0	0	0	0
1567	1568	1	0	0	0	0	0	0
1568	1569	1	0	0	0	0	0	0
1569	1570	1	0	0	0	0	0	0
1570	1571	1	0	0	0	0	0	0
1571	1572	1	0	0	0	0	0	0
1572	1573	1	0	0	0	0	0	0
1573	1574	1	0	0	0	0	0	0
1574	1575	1	0	0	0	0	0	0
1575	1576	1	0	0	0	0	0	0
1576	1577	1	0	0	0	0	0	0
1577	1578	1	0	0	0	0	0	0
1578	1579	1	0	0	0	0	0	0
1579	1580	1	0	0	0	0	0	0
1580	1581	1	0	0	0	0	0	0
1581	1582	1	0	0	0	0	0	0
1582	1583	1	0	0	0	0	0	0
1583	1584	1	0	0	0	0	0	0
1584	1585	1	0	0	0	0	0	0
1585	1586	1	0	0	0	0	0	0
1586	1587	1	0	0	0	0	0	0
1587	1588	1	0	0	0	0	0	0
1588	1589	1	0	0	0	0	0	0
1589	1590	1	0	0	0	0	0	0
1590	1591	1	0	0	0	0	0	0
1591	1592	1	0	0	0	0	0	0
1592	1593	1	0	0	0	0	0	0
1593	1594	1	0	0	0	0	0	0
1594	1595	1	0	0	0	0	0	0
1595	1596	1	0	0	0	0	0	0
1596	1597	1	0	0	0	0	0	0
1597	1598	1	0	0	0	0	0	0
1598	1599	1	0	0	0	0	0	0
1599	1600	1	0	0	0	0	0	0
1600	1601	1	0	0	0	0	0	0
1601	1602	1	0	0	0	0	0	0
1602	1603	1	0	0	0	0	0	0
1603	1604	1	0	0	0	0	0	0
1604	1605	1	0	0	0	0	0	0
1605	1606	1	0	0	0	0	0	0
1606	1607	1	0	0	0	0	0	0
1607	1608	1	0	0	0	0	0	0
1608	1609	1	0	0	0	0	0	0
1609	1610	1	0	0	0	0	0	0
1610	1611	1	0	0	0	0	0	0
1611	1612	1	0	0	0	0	0	0
1612	1613	1	0	0	0	0	0	0
1613	1614	1	0	0	0	0	0	0
1614	1615	1	0	0	0	0	0	0
1615	1616	1	0	0	0	0	0	0
1616	1617	1	0	0	0	0	0	0
1617	1618	1	0	0	0	0	0	0
1618	1619	1	0	0	0	0	0	0
1619	1620	1	0	0	0	0	0	0
1620	1621	1	0	0	0	0	0	0
1621	1622	1	0	0	0	0	0	0
1622	1623	1	0	0	0	0	0	0
1623	1624	1	0	0	0	0	0	0
1624	1625	1	0	0	0	0	0	0
1625	1626	1	0	0	0	0	0	0
1626	1627	1	0	0	0	0	0	0
1627	1628	1	0	0	0	0	0	0
1628	1629	1	0	0	0	0	0	0
1629	1630	1	0	0	0	0	0	0
1630	1631	1	0	0	0	0	0	0
1631	1632	1	0	0	0	0	0	0
1632	1633	1	0	0	0	0	0	0
1633	1634	1	0	0	0	0	0	0
1634	1635	1	0	0	0	0	0	0
1635	1636	1	0	0	0	0	0	0
1636	1637	1	0	0	0	0	0	0
1637	1638	1	0	0	0	0	0	0
1638	1639	1	0	0	0	0	0	0
1639	1640	1	0	0	0	0	0	0
1640	1641	1	0	0	0	0	0	0
1641	1642	1	0	0	0	0	0	0
1642	1643	1	0	0	0	0	0	0
1643	1644	1	0	0	0	0	0	0
1644	1645	1	0	0	0	0	0	0
1645	1646	1	0	0	0	0	0	0
1646	1647	1	0	0	0	0	0	0
1647	1648	1	0	0	0	0	0	0
1648	1649	1	0	0	0	0	0	0
1649	1650	1	0	0	0	0	0	0
1650	1651	1	0	0	0	0	0	0
1651	1652	1	0	0	0	0	0	0
1652	1653	1	0	0	0	0	0	0
1653	1654	1	0	0	0	0	0	0
1654	1655	1	0	0	0	0	0	0
1655	1656	1	0	0	0	0	0	0
1656	1657	1	0	0	0	0	0	0
1657	1658	1	0	0	0	0	0	0
1658	1659	1	0	0	0	0	0	0
1659	1660	1	0	0	0	0	0	0
1660	1661	1	0	0	0	0	0	0
1661	1662	1	0	0	0	0	0	0
1662	1663	1	0	0	0	0	0	0
1663	1664	1	0	0	0	0	0	0
1664	1665	1	0	0	0	0	0	0
1665	1666	1	0	0	0	0	0	0
1666	1667	1	0	0	0	0	0	0
1667	1668	1	0	0	0	0	0	0
1668	1669	1	0	0	0	0	0	0
1669	1670	1	0	0	0	0	0	0
1670	1671	1	0	0	0	0	0	0
1671	1672	1	0	0	0	0	0	0
1672	1673	1	0	0	0	0	0	0
1673	1674	1	0	0	0	0	0	0
1674	1675	1	0	0	0	0	0	0
1675	1676	1	0	0	0	0	0	0
\.


--
-- Data for Name: user_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_commands (id, type, fee_payer_id, source_id, receiver_id, fee_token, token, nonce, amount, fee, valid_until, memo, hash) FROM stdin;
\.


--
-- Name: balances_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.balances_id_seq', 1, false);


--
-- Name: blocks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.blocks_id_seq', 1, true);


--
-- Name: epoch_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.epoch_data_id_seq', 2, true);


--
-- Name: internal_commands_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.internal_commands_id_seq', 1, false);


--
-- Name: public_keys_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.public_keys_id_seq', 1676, true);


--
-- Name: snarked_ledger_hashes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.snarked_ledger_hashes_id_seq', 1, true);


--
-- Name: timing_info_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.timing_info_id_seq', 1675, true);


--
-- Name: user_commands_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_commands_id_seq', 1, false);


--
-- Name: balances balances_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.balances
    ADD CONSTRAINT balances_pkey PRIMARY KEY (id);


--
-- Name: balances balances_public_key_id_balance_block_id_block_height_block__key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.balances
    ADD CONSTRAINT balances_public_key_id_balance_block_id_block_height_block__key UNIQUE (public_key_id, balance, block_id, block_height, block_sequence_no, block_secondary_sequence_no);


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
-- Name: epoch_data epoch_data_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.epoch_data
    ADD CONSTRAINT epoch_data_pkey PRIMARY KEY (id);


--
-- Name: internal_commands internal_commands_hash_type_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.internal_commands
    ADD CONSTRAINT internal_commands_hash_type_key UNIQUE (hash, type);


--
-- Name: internal_commands internal_commands_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.internal_commands
    ADD CONSTRAINT internal_commands_pkey PRIMARY KEY (id);


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
-- Name: idx_balances_height_seq_nos; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_balances_height_seq_nos ON public.balances USING btree (block_height, block_sequence_no, block_secondary_sequence_no);


--
-- Name: idx_balances_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_balances_id ON public.balances USING btree (id);


--
-- Name: idx_balances_public_key_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_balances_public_key_id ON public.balances USING btree (public_key_id);


--
-- Name: idx_blocks_creator_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_blocks_creator_id ON public.blocks USING btree (creator_id);


--
-- Name: idx_blocks_height; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_blocks_height ON public.blocks USING btree (height);


--
-- Name: idx_blocks_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_blocks_id ON public.blocks USING btree (id);


--
-- Name: idx_blocks_internal_commands_block_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_blocks_internal_commands_block_id ON public.blocks_internal_commands USING btree (block_id);


--
-- Name: idx_blocks_internal_commands_internal_command_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_blocks_internal_commands_internal_command_id ON public.blocks_internal_commands USING btree (internal_command_id);


--
-- Name: idx_blocks_internal_commands_receiver_balance; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_blocks_internal_commands_receiver_balance ON public.blocks_internal_commands USING btree (receiver_balance);


--
-- Name: idx_blocks_parent_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_blocks_parent_id ON public.blocks USING btree (parent_id);


--
-- Name: idx_blocks_state_hash; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_blocks_state_hash ON public.blocks USING btree (state_hash);


--
-- Name: idx_blocks_user_commands_block_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_blocks_user_commands_block_id ON public.blocks_user_commands USING btree (block_id);


--
-- Name: idx_blocks_user_commands_fee_payer_balance; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_blocks_user_commands_fee_payer_balance ON public.blocks_user_commands USING btree (fee_payer_balance);


--
-- Name: idx_blocks_user_commands_receiver_balance; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_blocks_user_commands_receiver_balance ON public.blocks_user_commands USING btree (receiver_balance);


--
-- Name: idx_blocks_user_commands_source_balance; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_blocks_user_commands_source_balance ON public.blocks_user_commands USING btree (source_balance);


--
-- Name: idx_blocks_user_commands_user_command_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_blocks_user_commands_user_command_id ON public.blocks_user_commands USING btree (user_command_id);


--
-- Name: idx_chain_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_chain_status ON public.blocks USING btree (chain_status);


--
-- Name: idx_public_key_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_public_key_id ON public.timing_info USING btree (public_key_id);


--
-- Name: idx_public_keys_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_public_keys_id ON public.public_keys USING btree (id);


--
-- Name: idx_public_keys_value; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_public_keys_value ON public.public_keys USING btree (value);


--
-- Name: idx_snarked_ledger_hashes_value; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_snarked_ledger_hashes_value ON public.snarked_ledger_hashes USING btree (value);


--
-- Name: balances balances_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.balances
    ADD CONSTRAINT balances_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.blocks(id) ON DELETE CASCADE;


--
-- Name: balances balances_public_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.balances
    ADD CONSTRAINT balances_public_key_id_fkey FOREIGN KEY (public_key_id) REFERENCES public.public_keys(id);


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
-- Name: blocks_internal_commands blocks_internal_commands_receiver_balance_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocks_internal_commands
    ADD CONSTRAINT blocks_internal_commands_receiver_balance_fkey FOREIGN KEY (receiver_balance) REFERENCES public.balances(id) ON DELETE CASCADE;


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
-- Name: blocks_user_commands blocks_user_commands_fee_payer_balance_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocks_user_commands
    ADD CONSTRAINT blocks_user_commands_fee_payer_balance_fkey FOREIGN KEY (fee_payer_balance) REFERENCES public.balances(id) ON DELETE CASCADE;


--
-- Name: blocks_user_commands blocks_user_commands_receiver_balance_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocks_user_commands
    ADD CONSTRAINT blocks_user_commands_receiver_balance_fkey FOREIGN KEY (receiver_balance) REFERENCES public.balances(id) ON DELETE CASCADE;


--
-- Name: blocks_user_commands blocks_user_commands_source_balance_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocks_user_commands
    ADD CONSTRAINT blocks_user_commands_source_balance_fkey FOREIGN KEY (source_balance) REFERENCES public.balances(id) ON DELETE CASCADE;


--
-- Name: blocks_user_commands blocks_user_commands_user_command_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocks_user_commands
    ADD CONSTRAINT blocks_user_commands_user_command_id_fkey FOREIGN KEY (user_command_id) REFERENCES public.user_commands(id) ON DELETE CASCADE;


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
-- Name: timing_info timing_info_public_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.timing_info
    ADD CONSTRAINT timing_info_public_key_id_fkey FOREIGN KEY (public_key_id) REFERENCES public.public_keys(id);


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
-- PostgreSQL database dump complete
--

