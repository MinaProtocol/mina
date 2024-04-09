--
-- PostgreSQL database dump
--

-- Dumped from database version 12.16 (Ubuntu 12.16-0ubuntu0.20.04.1)
-- Dumped by pg_dump version 14.5

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
1	7	1440000000000	2	2	0	0	0
2	3	499750000000	3	2	0	0	1
3	5	1440000000000	3	2	1	0	0
4	5	1440250000000	3	2	2	0	0
5	3	499750000000	4	3	0	0	1
6	7	2880000000000	4	3	1	0	0
7	7	2880250000000	4	3	2	0	0
8	3	499500000000	5	4	0	0	2
9	3	499250000000	5	4	1	0	3
10	5	1440000000000	5	4	2	0	0
11	5	1440500000000	5	4	3	0	0
12	3	499000000000	6	5	0	0	4
13	5	2880500000000	6	5	1	0	0
14	5	2880750000000	6	5	2	0	0
15	3	498750000000	7	6	0	0	5
16	3	498500000000	7	6	1	0	6
17	7	4320250000000	7	6	2	0	0
18	7	4320750000000	7	6	3	0	0
19	3	498750000000	8	6	0	0	5
20	3	498500000000	8	6	1	0	6
21	5	4320750000000	8	6	2	0	0
22	5	4321250000000	8	6	3	0	0
23	3	498250000000	9	7	0	0	7
24	3	498000000000	9	7	1	0	8
25	3	497750000000	9	7	2	0	9
26	3	497500000000	9	7	3	0	10
27	7	5760750000000	9	7	4	0	0
28	7	5761750000000	9	7	5	0	0
29	3	497250000000	10	8	0	0	11
30	3	497000000000	10	8	1	0	12
31	5	4320750000000	10	8	2	0	0
32	5	4321250000000	10	8	3	0	0
33	3	496750000000	11	9	0	0	13
34	7	7201750000000	11	9	1	0	0
35	7	7202000000000	11	9	2	0	0
36	3	496500000000	12	10	0	0	14
37	3	496250000000	12	10	1	0	15
38	7	8642000000000	12	10	2	0	0
39	7	8642500000000	12	10	3	0	0
40	3	496000000000	13	11	0	0	16
41	3	495750000000	13	11	1	0	17
42	3	495500000000	13	11	2	0	18
43	3	495250000000	13	11	3	0	19
44	5	5761250000000	13	11	4	0	0
45	5	5762250000000	13	11	5	0	0
46	3	495000000000	14	12	0	0	20
47	3	494750000000	14	12	1	0	21
48	5	7202250000000	14	12	2	0	0
49	5	7202750000000	14	12	3	0	0
50	3	494500000000	15	13	0	0	22
51	3	494250000000	15	13	1	0	23
52	3	494000000000	15	13	2	0	24
53	3	493750000000	15	13	3	0	25
54	3	493500000000	15	13	4	0	26
55	3	493250000000	15	13	5	0	27
56	7	10082500000000	15	13	6	0	0
57	7	10084000000000	15	13	7	0	0
58	3	493000000000	16	14	0	0	28
59	5	8642750000000	16	14	1	0	0
60	5	8643000000000	16	14	2	0	0
61	3	492750000000	17	15	0	0	29
62	3	492500000000	17	15	1	0	30
63	7	11524000000000	17	15	2	0	0
64	7	11524500000000	17	15	3	0	0
65	3	492250000000	18	16	0	0	31
66	3	492000000000	18	16	1	0	32
67	3	491750000000	18	16	2	0	33
68	3	491500000000	18	16	3	0	34
69	3	491250000000	18	16	4	0	35
70	3	491000000000	18	16	5	0	36
71	3	490750000000	18	16	6	0	37
72	5	10083000000000	18	16	7	0	0
73	5	10084750000000	18	16	8	0	0
74	3	490500000000	19	17	0	0	38
75	3	490250000000	19	17	1	0	39
76	5	11524750000000	19	17	2	0	0
77	5	11525250000000	19	17	3	0	0
78	3	490000000000	20	18	0	0	40
79	7	12964500000000	20	18	1	0	0
80	7	12964750000000	20	18	2	0	0
81	3	489750000000	21	19	0	0	41
82	3	489500000000	21	19	1	0	42
83	3	489250000000	21	19	2	0	43
84	7	14404750000000	21	19	3	0	0
85	7	14405500000000	21	19	4	0	0
86	3	489000000000	22	20	0	0	44
87	3	488750000000	22	20	1	0	45
88	5	12965250000000	22	20	2	0	0
89	5	12965750000000	22	20	3	0	0
90	3	488500000000	23	21	0	0	46
91	5	14405750000000	23	21	1	0	0
92	5	14406000000000	23	21	2	0	0
93	3	488250000000	24	22	0	0	47
94	3	488000000000	24	22	1	0	48
95	5	15846000000000	24	22	2	0	0
96	5	15846500000000	24	22	3	0	0
97	3	487750000000	25	23	0	0	49
98	5	17286500000000	25	23	1	0	0
99	5	17286750000000	25	23	2	0	0
100	3	487500000000	26	24	0	0	50
101	3	487250000000	26	24	1	0	51
102	5	18726750000000	26	24	2	0	0
103	5	18727250000000	26	24	3	0	0
104	3	487000000000	27	25	0	0	52
105	7	15845500000000	27	25	1	0	0
106	7	15845750000000	27	25	2	0	0
107	3	487000000000	28	25	0	0	52
108	5	20167250000000	28	25	1	0	0
109	5	20167500000000	28	25	2	0	0
110	3	486750000000	29	26	0	0	53
111	3	486500000000	29	26	1	0	54
112	5	21607500000000	29	26	2	0	0
113	5	21608000000000	29	26	3	0	0
114	3	486250000000	30	27	0	0	55
115	5	23048000000000	30	27	1	0	0
116	5	23048250000000	30	27	2	0	0
117	3	486250000000	31	27	0	0	55
118	7	15845500000000	31	27	1	0	0
119	7	15845750000000	31	27	2	0	0
120	3	486000000000	32	28	0	0	56
121	3	485750000000	32	28	1	0	57
122	3	485500000000	32	28	2	0	58
123	7	17285750000000	32	28	3	0	0
124	7	17286500000000	32	28	4	0	0
125	3	485250000000	33	29	0	0	59
126	3	485000000000	33	29	1	0	60
127	5	23048000000000	33	29	2	0	0
128	5	23048500000000	33	29	3	0	0
129	3	484750000000	34	30	0	0	61
130	5	24488500000000	34	30	1	0	0
131	5	24488750000000	34	30	2	0	0
132	3	484500000000	35	31	0	0	62
133	3	484250000000	35	31	1	0	63
134	5	25928750000000	35	31	2	0	0
135	5	25929250000000	35	31	3	0	0
136	3	484000000000	36	32	0	0	64
137	7	18726500000000	36	32	1	0	0
138	7	18726750000000	36	32	2	0	0
139	3	483750000000	37	33	0	0	65
140	3	483500000000	37	33	1	0	66
141	5	25929750000000	37	33	2	0	0
142	5	27369750000000	37	33	3	0	0
\.


--
-- Data for Name: blocks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks (id, state_hash, parent_id, parent_hash, creator_id, block_winner_id, snarked_ledger_hash_id, staking_epoch_data_id, next_epoch_data_id, ledger_hash, height, global_slot, global_slot_since_genesis, "timestamp", chain_status) FROM stdin;
12	3NL83ZAAvRgscDm8r3Za3u4EmTBWBsonGN4jkUkpXUJLZ6guwsTt	11	3NK6sVZskURffmFYUFo3v7Hd2wa3qm2cSBvHTdCFogH622jcXs4w	7	6	1	1	13	jwHvK1cpQi2CQrWQGoBq1Y4gzRfYuS8YgoEiEuEpEptUhAit9aU	10	12	12	1701812137000	pending
13	3NKNisnFN3he58sRdPMKFxGfP3vLjetEYiohDMZ5T7Av9ihKxo77	12	3NL83ZAAvRgscDm8r3Za3u4EmTBWBsonGN4jkUkpXUJLZ6guwsTt	5	4	1	1	14	jwGtqzFfv8Gvu53amD63G6epWnkEg9hCpbXUrHCzqp53eJqE2T5	11	15	15	1701812677000	pending
14	3NKNi6ddyGuiUxdvfWQQNTTuTMdsbV14mhrGTCcvNXK5mg81HDYs	13	3NKNisnFN3he58sRdPMKFxGfP3vLjetEYiohDMZ5T7Av9ihKxo77	5	4	1	1	15	jxJ5VpwAPJisiTzpqmNihsGdfT3QA24YYrWZEbbFauASdYpAMZ8	12	16	16	1701812857000	pending
15	3NLaEXpaUeFyntvYPLcprHw4BzKAx4nkQJ3b1UbEXLhy9Re2F1P5	14	3NKNi6ddyGuiUxdvfWQQNTTuTMdsbV14mhrGTCcvNXK5mg81HDYs	7	6	1	1	16	jwkSsUEBwziRSbwNqVU38AoN18hAecZiCd6F3JVkfFCV7QbjH9i	13	20	20	1701813577000	pending
16	3NLijUWM6v9kjybFyDUnaoGQ6tPcsZMDLSsxw6GrE4GkCVGNH3a4	15	3NLaEXpaUeFyntvYPLcprHw4BzKAx4nkQJ3b1UbEXLhy9Re2F1P5	5	4	1	1	17	jwLegKi95eMevpzwaMifCfdFCswJNf6tXMJZUJXK1MvBCKs92ft	14	21	21	1701813757000	pending
17	3NKftnUqXk3m3AbVBBdEQxiUzjgS1veLtDsUjkGtgjNiYhnXSw4q	16	3NLijUWM6v9kjybFyDUnaoGQ6tPcsZMDLSsxw6GrE4GkCVGNH3a4	7	6	1	1	18	jx9UkMMNMHCdbbKSD7t8dpzHVHfMu1gzFk2A7iH6SNzPjFwK5PH	15	22	22	1701813937000	pending
18	3NKCGt1eQrQvFxfCe2sXQRf4MiAwa1xxwJF7zzSQ5n1wfesR6REc	17	3NKftnUqXk3m3AbVBBdEQxiUzjgS1veLtDsUjkGtgjNiYhnXSw4q	5	4	1	1	19	jxo2jCstDRRmXv82ra9WdPAswpCpsZfK74kqkGXL8k1ZXopZdcU	16	27	27	1701814837000	pending
19	3NKnkbTpBSFChnxa65dmH2HXKvMKHAH5bnhXQLqKSjBGwrHejkoh	18	3NKCGt1eQrQvFxfCe2sXQRf4MiAwa1xxwJF7zzSQ5n1wfesR6REc	5	4	1	1	20	jxyxCsv7ouHhNBVJ19pFLPHsLVwexHJ3hb7mkczKcnh1UnBMGqj	17	28	28	1701815017000	pending
20	3NKysxvkzTeHZZpHvnrkLVfVupDzLVQmybQJBFk3B8tNALatoWoZ	19	3NKnkbTpBSFChnxa65dmH2HXKvMKHAH5bnhXQLqKSjBGwrHejkoh	7	6	1	1	21	jwUpJtDHwFUxno74Mf84oTmo3f3HoE8e8hRjJoNiw2E9ajqPBN9	18	29	29	1701815197000	pending
21	3NLDJdrMsvdxEeYaartJv3ChyPaFhGVHoW5L8qQaHmx84rgL9XBn	20	3NKysxvkzTeHZZpHvnrkLVfVupDzLVQmybQJBFk3B8tNALatoWoZ	7	6	1	1	22	jxxECGup6PHRkAr9RMVfbQLsX7KAsSstajNvemHVmjVVWWoFKne	19	31	31	1701815557000	pending
22	3NKbbDjC6CbA3Hx6UX8TmBwVLRXKrjP5LR6exUpYNgJK3eJDEa5N	21	3NLDJdrMsvdxEeYaartJv3ChyPaFhGVHoW5L8qQaHmx84rgL9XBn	5	4	1	1	23	jxaYsJdiXYTCtCxAa7WJiiFrCpmambkSaodUBJhV7xpYafhJgsF	20	32	32	1701815737000	pending
23	3NKeQpcnXK78uDMcEodvMtCsXZPEYomvNB9maoRPwCj6ii6tPXa1	22	3NKbbDjC6CbA3Hx6UX8TmBwVLRXKrjP5LR6exUpYNgJK3eJDEa5N	5	4	1	1	24	jx7Kc65tvXuQGw8wLnkWPoEbc25q72qhvNB639NQBST2oZKHrqC	21	33	33	1701815917000	pending
24	3NKvX2SLs1gNqMAqu8S9GAjUvermc9rh8b76aeJBTcfwPMHNSM1K	23	3NKeQpcnXK78uDMcEodvMtCsXZPEYomvNB9maoRPwCj6ii6tPXa1	5	4	1	1	25	jwRiQ9u5CW9qxcde1nD7GaSaPmcVJJSKu4P3nz2NGjJTzvmRrjv	22	34	34	1701816097000	pending
25	3NKyYu8qBKGaNMuP2ZXVoYARcSxGWoZV4ovsmVJt6RU6sYzt1k3x	24	3NKvX2SLs1gNqMAqu8S9GAjUvermc9rh8b76aeJBTcfwPMHNSM1K	5	4	1	1	26	jx8urzdmA7FqCnk2XZ4pFtJA75Gb9ME7fN55fZ8nPN4Bsv5BsUE	23	35	35	1701816277000	pending
26	3NKmMz1HwhusDCrJGbit1EMpBkGni2Srgpmo6LRhTikyVDnK2zJ6	25	3NKyYu8qBKGaNMuP2ZXVoYARcSxGWoZV4ovsmVJt6RU6sYzt1k3x	5	4	1	1	27	jxaBpRgE9G2Cy94mRdU4nBPWUTKHd1izxa8zLSz6PdsypeYCpDz	24	36	36	1701816457000	pending
27	3NL6JZt4TornoTgerZKjD6hNnVHHo8fbmS8TVKWWvUA8nAMi5tDy	26	3NKmMz1HwhusDCrJGbit1EMpBkGni2Srgpmo6LRhTikyVDnK2zJ6	7	6	1	1	28	jx4DgKpMAW65wi3DPafEv5JkZeZXPBs81r87ZhgdA6WaFKr5wnN	25	37	37	1701816637000	pending
28	3NLQJcLCuyrF5bz8n19jDsgVEWyso5mj3jhJVhdsrWWVCPNAHm9E	26	3NKmMz1HwhusDCrJGbit1EMpBkGni2Srgpmo6LRhTikyVDnK2zJ6	5	4	1	1	29	jwkqvn1wq1vHorEb79CQbpUJzMGxBNkyw4eznM7okaMmG38qiCB	25	37	37	1701816637000	pending
29	3NKuVByEQapzD5qhBTC3AcWNm2Vk6rP5ortQ5Xp6RDp7TYgBU2wh	28	3NLQJcLCuyrF5bz8n19jDsgVEWyso5mj3jhJVhdsrWWVCPNAHm9E	5	4	1	1	30	jw93gGwTSzGNeeLp85uqqyzxMEBzjQYLcBUau7E8Uz1XUGL4Sks	26	38	38	1701816817000	pending
1	3NLP2r9zSufMJ6vVTkWzZkCLz5dfFQCai2ktshm6h88uaoaznCR8	\N	3NKGvnQVeeCJrApDRujsfefRgG4fJDbffLaZPNXnLKrpeiBEohQZ	1	1	1	1	2	jxYxRMdNmxvWcr8HEHR9d7zX2xvymJq6tF7sNcc7NDN2FsvjPLv	1	0	0	1701809977000	canonical
2	3NKNKuPaeRRPyVK19G1mphWD4YwYbqQiG7PCNBS9mmzueQCUk663	1	3NLP2r9zSufMJ6vVTkWzZkCLz5dfFQCai2ktshm6h88uaoaznCR8	7	6	1	1	3	jxPqCjSxqBVNDcFjjfgiUvPXxK47UersfCcNaC3H8zDDN2kbNbC	2	1	1	1701810288753	canonical
4	3NLbkqZziafc2TjT8S3YcSrctmQzH3ZEfvJLRExLWtujnqaWhPuw	2	3NKNKuPaeRRPyVK19G1mphWD4YwYbqQiG7PCNBS9mmzueQCUk663	7	6	1	1	5	jwenzQYYTSc6u8BVygkA8wiV3xiEYyq5Wzv847N1jsZYKRZRUHb	3	3	3	1701810517000	canonical
5	3NKeswcv8F8FK8anUFL45UwrSLCHVDDvo5Pt6CZV3nzxpByAMNCd	4	3NLbkqZziafc2TjT8S3YcSrctmQzH3ZEfvJLRExLWtujnqaWhPuw	5	4	1	1	6	jy28tjCxrv4TA4RUYcunSeKtiXufkVYgvCtJisokXH4v8qkfL1N	4	4	4	1701810697000	canonical
6	3NKRFeyyzpqX3nJCZzMk8ZLJEbR6XTvWjQ72Gm6zgYssF6LjMJH7	5	3NKeswcv8F8FK8anUFL45UwrSLCHVDDvo5Pt6CZV3nzxpByAMNCd	5	4	1	1	7	jxdVmeg2AVqidgNVjrrApL6KpnruwjjFsQRjAGjM5n5z7PegpBi	5	5	5	1701810877000	canonical
7	3NLsyGpErHAYByfVWPSthc8tp7jB1jwAEGyqVfijjJWLdLZJP459	6	3NKRFeyyzpqX3nJCZzMk8ZLJEbR6XTvWjQ72Gm6zgYssF6LjMJH7	7	6	1	1	8	jxf86St85KBWpbmhZtL7dwbNAwKtSkWn3xZfginUosVCjkAZTeG	6	6	6	1701811057000	canonical
8	3NK3qaV4ArMXKWJ9EzFnsnxyDhMkBQhxqxw32yqCr5unRArVvHJF	6	3NKRFeyyzpqX3nJCZzMk8ZLJEbR6XTvWjQ72Gm6zgYssF6LjMJH7	5	4	1	1	9	jwDrfrjR1f27C9rNLBHkNJey5iF4pdpSMKdkBXizBo9q5hRW6Lw	6	6	6	1701811057000	orphaned
9	3NLbYdtrpCsdZLZGWBP3gTqDrQ2cEcPuJ9Umc8fbKaiiYJhtCgss	7	3NLsyGpErHAYByfVWPSthc8tp7jB1jwAEGyqVfijjJWLdLZJP459	7	6	1	1	10	jwDFyNB4a9QR8FFz1TvoUQxpkz8nwDbfTxS7EdgBdNnLaSZUbiN	7	9	9	1701811597000	canonical
10	3NLWxDk2CcGkmDTR8Hh1aatVEAsVf4GxgoR1yc5k6Xm59AxZLRn9	9	3NLbYdtrpCsdZLZGWBP3gTqDrQ2cEcPuJ9Umc8fbKaiiYJhtCgss	5	4	1	1	11	jwdZyzdrXTrvazQQuvvhyZVQBDVab7yaV54qdZBL99y9vTyeXbu	8	10	10	1701811777000	canonical
11	3NK6sVZskURffmFYUFo3v7Hd2wa3qm2cSBvHTdCFogH622jcXs4w	10	3NLWxDk2CcGkmDTR8Hh1aatVEAsVf4GxgoR1yc5k6Xm59AxZLRn9	7	6	1	1	12	jwQ69P2rU3AZP7bHUZ5JUGzAinGik3wJArq6L5ZAqdcUvWwVuDr	9	11	11	1701811957000	canonical
30	3NKMAcPhfSfSVoXiTD6fqJXDuhoGvZfgx3sEHoaa3KFU7ZzJ55zQ	29	3NKuVByEQapzD5qhBTC3AcWNm2Vk6rP5ortQ5Xp6RDp7TYgBU2wh	5	4	1	1	31	jxAFtqo4T28Dbt4mc9nVRZDrvZ1Y5AVsd8RosRB2HaGhRT3w9Qf	27	39	39	1701816997000	pending
3	3NLMC6seTkwjVZsF5T7xGy6oT91M6R9hGuSqQSaURkiTLcCBRxBs	1	3NLP2r9zSufMJ6vVTkWzZkCLz5dfFQCai2ktshm6h88uaoaznCR8	5	4	1	1	4	jw7tGRCxtBEPbs73ms7kZuzYBSKevTxa5fK2hbjztPwJtuK3Vk6	2	2	2	1701810359603	orphaned
31	3NLn1yE1asq4C9QdRmxAh4S4Af4bHvA1QHJmwdqGj4PDCrBmAChn	29	3NKuVByEQapzD5qhBTC3AcWNm2Vk6rP5ortQ5Xp6RDp7TYgBU2wh	7	6	1	1	32	jx4pbSuJfhrNgG5EhDgP42LopAsfVrFMww9zWhJj8paxPmaUhC4	27	39	39	1701816997000	pending
32	3NLWpp5S6ENGtEfpxasns4y5bvdHydqfeiVnFp3V3GEBXQAggaA5	31	3NLn1yE1asq4C9QdRmxAh4S4Af4bHvA1QHJmwdqGj4PDCrBmAChn	7	6	1	1	33	jwHyByDPwrRgS4Pf7231qoDXWY2Atw89DLdDZXH4PcaceYL7dGK	28	41	41	1701817357000	pending
33	3NLcReaLZ8kbBWa4hdDEtLMwV4jqHC3wcRGhsXgVizeEyBaneaix	32	3NLWpp5S6ENGtEfpxasns4y5bvdHydqfeiVnFp3V3GEBXQAggaA5	5	4	1	1	34	jwSQfTdUfNQoEFemDfYEUMktsFDRoWPXu7DexSJCerrW8FqJ9ba	29	42	42	1701817537000	pending
34	3NKr5kwjLsu93DaEyaTkPMRJpjnSPxCvMADRNpuJz7BKXGiCiAia	33	3NLcReaLZ8kbBWa4hdDEtLMwV4jqHC3wcRGhsXgVizeEyBaneaix	5	4	1	1	35	jw6hMJ1DEVL8ZtrUWdk8cALX9FZfSjEB1oFTAYseba4NxX8spHA	30	43	43	1701817717000	pending
35	3NK4LdnNkCYukjH2jPTyahpWR1NSMg3boRNTBcvKXfhXK2WknDTa	34	3NKr5kwjLsu93DaEyaTkPMRJpjnSPxCvMADRNpuJz7BKXGiCiAia	5	4	1	1	36	jwq7PPJ9UM9TLM98FT6iBRbbH2397sAF7UvEXRx8A2M7LUNzQJA	31	44	44	1701817897000	pending
36	3NLB1P3mCSHp9kbKkTvQLpyv6vpvezBmEtj7FCuyGRK16qvVT6yJ	35	3NK4LdnNkCYukjH2jPTyahpWR1NSMg3boRNTBcvKXfhXK2WknDTa	7	6	1	1	37	jwt2An5C48nPpSqQ5DXm5ozYXrJjfXTic3utC6tkSbUDosdjy9p	32	45	45	1701818077000	pending
37	3NLbBRi3yD7Be22Zwqh74VCrxEmT6dRW4k2Fdu1hX5H85c3q3WVq	36	3NLB1P3mCSHp9kbKkTvQLpyv6vpvezBmEtj7FCuyGRK16qvVT6yJ	5	4	1	1	38	jxjozjQyyYdKm5fyWBe2UNb3jKRzJrA2fWkm7uVEUaaLfqVZ39v	33	46	46	1701818257000	pending
\.


--
-- Data for Name: blocks_internal_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_internal_commands (block_id, internal_command_id, sequence_no, secondary_sequence_no, receiver_account_creation_fee_paid, receiver_balance) FROM stdin;
2	1	0	0	\N	1
3	2	1	0	\N	3
3	3	2	0	\N	4
4	1	1	0	\N	6
4	4	2	0	\N	7
5	2	2	0	\N	10
5	5	3	0	\N	11
6	2	1	0	\N	13
6	3	2	0	\N	14
7	1	2	0	\N	17
7	6	3	0	\N	18
8	2	2	0	\N	21
8	5	3	0	\N	22
9	1	4	0	\N	27
9	7	5	0	\N	28
10	2	2	0	\N	31
10	5	3	0	\N	32
11	1	1	0	\N	34
11	4	2	0	\N	35
12	1	2	0	\N	38
12	6	3	0	\N	39
13	2	4	0	\N	44
13	8	5	0	\N	45
14	2	2	0	\N	48
14	5	3	0	\N	49
15	1	6	0	\N	56
15	9	7	0	\N	57
16	2	1	0	\N	59
16	3	2	0	\N	60
17	1	2	0	\N	63
17	6	3	0	\N	64
18	2	7	0	\N	72
18	10	8	0	\N	73
19	2	2	0	\N	76
19	5	3	0	\N	77
20	1	1	0	\N	79
20	4	2	0	\N	80
21	1	3	0	\N	84
21	11	4	0	\N	85
22	2	2	0	\N	88
22	5	3	0	\N	89
23	2	1	0	\N	91
23	3	2	0	\N	92
24	2	2	0	\N	95
24	5	3	0	\N	96
25	2	1	0	\N	98
25	3	2	0	\N	99
26	2	2	0	\N	102
26	5	3	0	\N	103
27	1	1	0	\N	105
27	4	2	0	\N	106
28	2	1	0	\N	108
28	3	2	0	\N	109
29	2	2	0	\N	112
29	5	3	0	\N	113
30	2	1	0	\N	115
30	3	2	0	\N	116
31	1	1	0	\N	118
31	4	2	0	\N	119
32	1	3	0	\N	123
32	11	4	0	\N	124
33	2	2	0	\N	127
33	5	3	0	\N	128
34	2	1	0	\N	130
34	3	2	0	\N	131
35	2	2	0	\N	134
35	5	3	0	\N	135
36	1	1	0	\N	137
36	4	2	0	\N	138
37	5	2	0	\N	141
37	2	3	0	\N	142
\.


--
-- Data for Name: blocks_user_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_user_commands (block_id, user_command_id, sequence_no, status, failure_reason, fee_payer_account_creation_fee_paid, receiver_account_creation_fee_paid, created_token, fee_payer_balance, source_balance, receiver_balance) FROM stdin;
3	1	0	applied	\N	\N	\N	\N	2	2	2
4	1	0	applied	\N	\N	\N	\N	5	5	5
5	2	0	applied	\N	\N	\N	\N	8	8	8
5	3	1	applied	\N	\N	\N	\N	9	9	9
6	4	0	applied	\N	\N	\N	\N	12	12	12
7	5	0	applied	\N	\N	\N	\N	15	15	15
7	6	1	applied	\N	\N	\N	\N	16	16	16
8	5	0	applied	\N	\N	\N	\N	19	19	19
8	6	1	applied	\N	\N	\N	\N	20	20	20
9	7	0	applied	\N	\N	\N	\N	23	23	23
9	8	1	applied	\N	\N	\N	\N	24	24	24
9	9	2	applied	\N	\N	\N	\N	25	25	25
9	10	3	applied	\N	\N	\N	\N	26	26	26
10	11	0	applied	\N	\N	\N	\N	29	29	29
10	12	1	applied	\N	\N	\N	\N	30	30	30
11	13	0	applied	\N	\N	\N	\N	33	33	33
12	14	0	applied	\N	\N	\N	\N	36	36	36
12	15	1	applied	\N	\N	\N	\N	37	37	37
13	16	0	applied	\N	\N	\N	\N	40	40	40
13	17	1	applied	\N	\N	\N	\N	41	41	41
13	18	2	applied	\N	\N	\N	\N	42	42	42
13	19	3	applied	\N	\N	\N	\N	43	43	43
14	20	0	applied	\N	\N	\N	\N	46	46	46
14	21	1	applied	\N	\N	\N	\N	47	47	47
15	22	0	applied	\N	\N	\N	\N	50	50	50
15	23	1	applied	\N	\N	\N	\N	51	51	51
15	24	2	applied	\N	\N	\N	\N	52	52	52
15	25	3	applied	\N	\N	\N	\N	53	53	53
15	26	4	applied	\N	\N	\N	\N	54	54	54
15	27	5	applied	\N	\N	\N	\N	55	55	55
16	28	0	applied	\N	\N	\N	\N	58	58	58
17	29	0	applied	\N	\N	\N	\N	61	61	61
17	30	1	applied	\N	\N	\N	\N	62	62	62
18	31	0	applied	\N	\N	\N	\N	65	65	65
18	32	1	applied	\N	\N	\N	\N	66	66	66
18	33	2	applied	\N	\N	\N	\N	67	67	67
18	34	3	applied	\N	\N	\N	\N	68	68	68
18	35	4	applied	\N	\N	\N	\N	69	69	69
18	36	5	applied	\N	\N	\N	\N	70	70	70
18	37	6	applied	\N	\N	\N	\N	71	71	71
19	38	0	applied	\N	\N	\N	\N	74	74	74
19	39	1	applied	\N	\N	\N	\N	75	75	75
20	40	0	applied	\N	\N	\N	\N	78	78	78
21	41	0	applied	\N	\N	\N	\N	81	81	81
21	42	1	applied	\N	\N	\N	\N	82	82	82
21	43	2	applied	\N	\N	\N	\N	83	83	83
22	44	0	applied	\N	\N	\N	\N	86	86	86
22	45	1	applied	\N	\N	\N	\N	87	87	87
23	46	0	applied	\N	\N	\N	\N	90	90	90
24	47	0	applied	\N	\N	\N	\N	93	93	93
24	48	1	applied	\N	\N	\N	\N	94	94	94
25	49	0	applied	\N	\N	\N	\N	97	97	97
26	50	0	applied	\N	\N	\N	\N	100	100	100
26	51	1	applied	\N	\N	\N	\N	101	101	101
27	52	0	applied	\N	\N	\N	\N	104	104	104
28	52	0	applied	\N	\N	\N	\N	107	107	107
29	53	0	applied	\N	\N	\N	\N	110	110	110
29	54	1	applied	\N	\N	\N	\N	111	111	111
30	55	0	applied	\N	\N	\N	\N	114	114	114
31	55	0	applied	\N	\N	\N	\N	117	117	117
32	56	0	applied	\N	\N	\N	\N	120	120	120
32	57	1	applied	\N	\N	\N	\N	121	121	121
32	58	2	applied	\N	\N	\N	\N	122	122	122
33	59	0	applied	\N	\N	\N	\N	125	125	125
33	60	1	applied	\N	\N	\N	\N	126	126	126
34	61	0	applied	\N	\N	\N	\N	129	129	129
35	62	0	applied	\N	\N	\N	\N	132	132	132
35	63	1	applied	\N	\N	\N	\N	133	133	133
36	64	0	applied	\N	\N	\N	\N	136	136	136
37	65	0	applied	\N	\N	\N	\N	139	139	139
37	66	1	applied	\N	\N	\N	\N	140	140	140
\.


--
-- Data for Name: epoch_data; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.epoch_data (id, seed, ledger_hash_id) FROM stdin;
1	2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA	1
2	2vaRh7FQ5wSzmpFReF9gcRKjv48CcJvHs25aqb3SSZiPgHQBy5Dt	1
3	2vbjsXMN1DWTe42P9UyeGtxHTs4J6Xht3vvm9yWoBN84CG8eGWxD	1
4	2vaiRVqHRfhcJAvWL3wJweCFX3exKMnLkvGh3Xsn5v4nkrnsoA2s	1
5	2vbScG5hPwLptFmq43UWssQLju6AP2PzvJ9qj8zzQCmJp7Xez6jz	1
6	2vbpqkbk2GFwNXGqfFgov3XZc7qZ8dchsCYbAkXFThF5sRaXs1h4	1
7	2vbHAozjdmLYJMgQTysATqc9XmioU2r3HaHSRNyy3WhH8bGNsvTJ	1
8	2vbPLMiJP66LZKgPeSC6ut8pKABSY19Z9Ur1H318oqgjnXhELko3	1
9	2vbJFwE8EEm5EN7LhP8XkxZ9chms8heVqizZqF2rwh5YH7vRuhkH	1
10	2vaFmdaKQXmL6YW6GmjpQQKK43ji5tHXy7jmgqMUjWrAbLJN6r8G	1
11	2vaZgVrECZWCsrp6zTr6s1JSrqEoCEd8cJ6D8oyM7jj3AtQTCcz3	1
12	2vav62vBU9PeT68KNrLFnYcRVotxdTh3QBw3ch65Y74UAfHV32qG	1
13	2vb3khA9hU2UYmHDcuBtzHeDHnr5YfVLwDLdaLncMBDx4p3tApAR	1
14	2vbbej1HjCJVjw8939993cQHgndunaD8Tx2raLsovbWkLJEdRFqR	1
15	2vbKKjJVJERJ3fJg5qRdfuUjth7dww9SKBkWqErkwcrGRS3CCqu3	1
16	2vakNHUEKLib5k2ZyLNMsnBsyhJngmcRrHxmeu8rhPTeyAtZZqc9	1
17	2vaKceW3hN87dq4rvUT3nmtoXYfZudaK6UiXtn92p9ARVwb6XiwZ	1
18	2vapffuZrjpxFosqok7TmfFm8BYRd5LJuvpoyJToHQw2HnWVLPuf	1
19	2vasZWhn14uhPGjbyPw8pfpKknpqE7JoLUbiTrkdajRtgyNaHdwU	1
20	2vb5ZZoqnUMpGvVHS4domdezPKxmyEJaK5D5AiVoiXGubveKXKWo	1
21	2vbdeNLVRpFWdCMxrGyFn97zy9pVxfmWkDZJ51fX1Vr2Pk3Do16f	1
22	2vafKwfWqWZQuPZ8m2R8Z1afLk6nn6ufXeZzkGgHcvJSPmNFMzqU	1
23	2vaghu99BY8peYRM6H25563V9oXyhYWDnMw8811xwMYq6DhMKtTE	1
24	2vbtDZu8MfntDXZP376UpxBxkRwMki6VpvhPADet2oin6W2n7YFu	1
25	2vaNyiKL5CFU3qjAf8cw3a3SeDGj3zGMdrPzMVcdaZT2CCQtdVaG	1
26	2vadsNXKZ98VapVFgqBVC6QktyzqS6LWLxcg8Frii9AYapkEr7Bb	1
27	2vbGQ6GCvtFbm3pGiv8UjCDdfwZbnM1hPUELde5hvESrKLoHzHur	1
28	2vaabNdgstCpgjmg8D6VWTtNrnUa6Y5EQ78TQrQhCHvGmWstbUAz	1
29	2vaUyr46Fa3u5ZpxXQ3obe3DrMYErsdLX6ZjTSiouybbGy4v4Awk	1
30	2vbqvZ6Es6f3EjRJBaqHzHm3qfPT5Wh6d4TBqJdudHF4iwZw7vTa	1
31	2vaz4oZXPb4gjKh4z8ZS8gNrhnW6795mzRQj6c1Hfv2izxJJ2orr	1
32	2vaB8QehVZKpt16bbmDw3xoincwu6VCjxaA8YArnPvRqvmfVnQP2	1
33	2vaXyJB3q93eZGT5DnYFHkbvrqxZmkP7pd94k4Y5znVUt8EehoHq	1
34	2vbN5LthZDL8VALS5KZ5MeVKyJSX8AcCNmUNRVVrfHBLfh75gJ57	1
35	2vaNoB4g5gwbNyyYKR76H2fACiVmvgmjhikDT9C8efrxieJWi1Sh	1
36	2vabzVP1EJWRVtXeNJBisMj7aLbi45uHbUUW4K7Ss7MhZqL3b2cK	1
37	2vbGPxi5K6b4VaLGP4AR15xNHrFaXpF2LhHbS35EMXyxiBaxwE9H	1
38	2vbW9prqYwX8K1t5CHBdwTqHZHKmAZ1QVZxAfzc6Mt8fMDr24hiv	1
\.


--
-- Data for Name: internal_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.internal_commands (id, type, receiver_id, fee, token, hash) FROM stdin;
1	coinbase	7	1440000000000	1	CkpYqDGL1hz9ssv1p1JJLpWgf2WaGoPZF9NVhtnjx6Wmfp7H3VJr6
2	coinbase	5	1440000000000	1	CkpZnoExyWir7oox2fQbjJrhkzmX3F3Co19pjEZow14DQtUat6JLk
3	fee_transfer	5	250000000	1	CkpZxDDWoc2czr2cKop1QcS5Q5xxW3TD8LNTHF9vkHC2H8eEriAaG
4	fee_transfer	7	250000000	1	CkpYjR4hAMT5ZCs9GQdTdTWFrnB3sErQ2UnhJjUBXtENWY5BRJvAT
5	fee_transfer	5	500000000	1	CkpZW25Kb2rUg9tmEZ3CHM7yVQB79DUwV6WbvFXUw6BUshVQGnaeM
6	fee_transfer	7	500000000	1	CkpYc6ssKYsEdE7MS77KVGYqEC8w1QtXCVbu7pAmx4CtomFGcrBsk
7	fee_transfer	7	1000000000	1	CkpZWzRYZ4YF4GsdqZPompVtdj4rHqGBTGacUTJ8mBRkdVUcCQjvX
8	fee_transfer	5	1000000000	1	Ckpa2tvwZepRgz2zGN3eUSh7YDLGHkFZ3dHYZPnG6ip8j7hN5CzQ4
9	fee_transfer	7	1500000000	1	CkpYYDxcfnWNunbvCCUpHUfhsKe5tQ6k2K2xnJfMjDDU9y9hhaEya
10	fee_transfer	5	1750000000	1	CkpZLsmbr8mCqWEehx5qGfq5Q7MJ4NsdbncFYomdz4cPotCLxvWCy
11	fee_transfer	7	750000000	1	Ckpa7CeVQcaxySM5V8868rAUd15Ujs9pTNJkgHASbMvHBfNg7gpPc
\.


--
-- Data for Name: public_keys; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.public_keys (id, value) FROM stdin;
1	B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg
2	B62qoRdtEBWMPRiZvxrihxYzzU2hW7KBtqxNfhfwJKNkVwsJdgYmYmL
3	B62qmxTL9HvQDEvdNWjgon9ouZhTfssAHzyUqmqtjjGFEsevEAYBMUt
4	B62qrgvZn4ty5h8KwMDuz61naGDAdqcXcQmxsZoFx8JFnhZ2ohFEdkZ
5	B62qnGkv9fhuW86rWN3nYiaqD8A1m9dFAyWW9nATnYCj3HNtXrLUe1y
6	B62qnUczQQgdSrP54pvyJGT8oeCNS5eTUu95bR3y9w2TYgDCq6PpVK5
7	B62qnzmHfkfVEAGhSgu5bLdsanaH6vQ1GDgdNDbKAiewPcfmMf2CXpA
\.


--
-- Data for Name: snarked_ledger_hashes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.snarked_ledger_hashes (id, value) FROM stdin;
1	jxYxRMdNmxvWcr8HEHR9d7zX2xvymJq6tF7sNcc7NDN2FsvjPLv
\.


--
-- Data for Name: timing_info; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.timing_info (id, public_key_id, token, initial_balance, initial_minimum_balance, cliff_time, cliff_amount, vesting_period, vesting_increment) FROM stdin;
1	2	1	65500000000000	0	0	0	0	0
2	3	1	500000000000	0	0	0	0	0
3	4	1	11550000000000000	0	0	0	0	0
4	5	1	0	0	0	0	0	0
5	6	1	11550000000000000	0	0	0	0	0
6	7	1	0	0	0	0	0	0
\.


--
-- Data for Name: user_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_commands (id, type, fee_payer_id, source_id, receiver_id, fee_token, token, nonce, amount, fee, valid_until, memo, hash) FROM stdin;
1	payment	3	3	3	1	1	0	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaAJBhQn35E3WU4QyZMkTWEEShqfpMS6nnwGgqPeomdK5RP7int
2	payment	3	3	3	1	1	1	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYT27qjF5zPX5UQiHoit6o5FFLVynhJezgLTYK7ZBtZRACqMjBK
3	payment	3	3	3	1	1	2	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaKLcdPgfoka3UBLouMsD2FDtBd6TrCcsvW1g32QR9MfZyNotB5
4	payment	3	3	3	1	1	3	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYqJVqR1xs8huc8Dt9YgvJH2wBx4z5fdnmszYPyHdZH1ZLdxm1K
5	payment	3	3	3	1	1	4	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ3kEWWLsWnNpx8PdNMePBZVCk1qD6JyDXg7N7fEdfoey1V5qoM
6	payment	3	3	3	1	1	5	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZPU33dqbYzMiCpHKQm3sHPzDjiwVLSfyB5rMDs3MdydK2cTXBn
7	payment	3	3	3	1	1	6	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYwG1wasH5y2uiDugnjhK4umscjiUi9yHmHWatiS1GpS2jqBXna
8	payment	3	3	3	1	1	7	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZUcHXGuZp9MRmMTsTqZ6zH6C9suF4mFNeQiK35W4PB5pnvVMoS
9	payment	3	3	3	1	1	8	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaBgCCiR7ycTiPRFw7Usbc3nSPuM3SvAJFVFGBHj9Gi8FBzFMxt
10	payment	3	3	3	1	1	9	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZPc5UbcYMXm5Q9qgP5M9kd2my6akaBB4w3Ra21ZSuHPbm8qD6u
11	payment	3	3	3	1	1	10	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYuwB9DXL82v3HGamBWz3ySL434mPFNZWfKMyjXaoUd5fnThbDZ
12	payment	3	3	3	1	1	11	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaJd1gJUnREqN4uie45CsCGZqnEuEBC5Rr4gyWper2CfPvCAUUV
13	payment	3	3	3	1	1	12	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZGTp9crvW5nRMcZEru9XLNMT7MSZtBXpByTq1cVj1GNESYjDYG
14	payment	3	3	3	1	1	13	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZVfhKzA6JjtfqpQ3xhbzhggAz6WJvQBRMVmTAVwdfJ4i4fYMzs
15	payment	3	3	3	1	1	14	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZUNnoeE1275Yd1gxKuU4Ru21GAKUopKCSTZbbMwPjVoPQcRdyV
16	payment	3	3	3	1	1	15	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZyzwW2vMLYhLaf3XFDfazocF1d35RSRrQn3JAt5gXCMejSKdf9
17	payment	3	3	3	1	1	16	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZh9K99MNDYmG1hUKgdbX8Zcsa2t3svPB8cUoPGwh9Wr8JKa5V9
18	payment	3	3	3	1	1	17	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa3z5AJysAmLw3cJuSeZXxmmXciv8kUato676pLfYCaA3g1f4t2
19	payment	3	3	3	1	1	18	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZNBrZYjD8Np3qHtqmNz8AjsJnfXyVoyrHYEs16hfpSU8P41iWb
20	payment	3	3	3	1	1	19	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZPZQLHPr3rjapNYgrEESEcTAwjz8iPb7zp2g3uPyhsV1ZJMiSJ
21	payment	3	3	3	1	1	20	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa315wLBAQhzRrjDYvmvFCRzZ7Jmtv2CirtZZfnbajWborx2A4e
22	payment	3	3	3	1	1	21	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYpxv6zTrNDbBjZvkMEE2dBjN4rP3qYo86LySro9kGunocbk6z5
23	payment	3	3	3	1	1	22	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYsj6brkaGcHJgH9o4MxkBfGxHBpuMzThdcnoiqYXR3qVp5bYvW
24	payment	3	3	3	1	1	23	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYY9bG7EGwHb5Nvyg3nMSC54Ref5ZNBaE9CYaeQJ5FQibrM73mQ
25	payment	3	3	3	1	1	24	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa9QPw31MF43oLvwyFKp3Z8jt3Bf7acFQseoyrqXapcdAr9EZR8
26	payment	3	3	3	1	1	25	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYTCNAJqBaBaBCry7N658HvbZKido9oi6o6oaSFXouD8F9TXV2U
27	payment	3	3	3	1	1	26	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaEZwPCRCXU23UrJb2ftCCjeWwCJtFVpD446QtXFftiptfgtSzL
28	payment	3	3	3	1	1	27	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZinYujQMq8ekry92gAPD3cZgUps122z2GVCWjdaUZm5rMHiqde
29	payment	3	3	3	1	1	28	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYWzfhth4PDQ287sk7jyakhTy8UvDa3H9NNaWSZT6UzurXW74bL
30	payment	3	3	3	1	1	29	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaG8R4rM7KkU2M47P7BPdBD3AtLToFWcYD4DmUPKRoh1Vho53jn
31	payment	3	3	3	1	1	30	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZScvbpCBHjM9pUKYvFv51Lii6QvCcuCon1antNgA8UwbJfXb2w
32	payment	3	3	3	1	1	31	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYxWg8sooiGRD3D9TZYkcrysYdk3en9mGs2WZCSFfwKERUKsTJ6
33	payment	3	3	3	1	1	32	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYyrzn14wmjjChcm8f2WLnWLun9Ag8ggcpaYv3N4prg5eh3B8x2
34	payment	3	3	3	1	1	33	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYk8yxs2achihjem9VE1rz2Rf8jKvQcQGTSgCxc4Y8znnU6Uzk8
35	payment	3	3	3	1	1	34	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYuWyd5kwszLTvVUtmrksYBsouJ8C57hUyYkQS5CQAjDU9FH72D
36	payment	3	3	3	1	1	35	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ76gfmLiBZED4hXEHGqh9ZokQtMg25GAUYQvVpvXR8ZQaG9swJ
37	payment	3	3	3	1	1	36	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZR6UgTdW4f7zNtXhxoCi1QX95PVeCemuoApvdCaQAvUMUvmpLe
38	payment	3	3	3	1	1	37	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYQn9xjktrkNen1m8XiQqzvA2QgJM7dZU5nTsX2nSbAewCSxepC
39	payment	3	3	3	1	1	38	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZVMV4DpjQmGDd9o5LXHcyArV9HEGNt8rYRoqzsxTYHoyuPPF6o
40	payment	3	3	3	1	1	39	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZjLc3uTBptdSVd4zWLoGK17LQ5wZ1PYYqtSuTJE8wtcyKPgNNd
41	payment	3	3	3	1	1	40	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZc5bvR2hAV9wG2yApEmhwgBdX1UZZavmjEebxdt9DudzY6Cjmi
42	payment	3	3	3	1	1	41	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ1ykwSyvm9cSomtKsmH65uHGgCZ1DHQtSvPdqrN8P7fwjScNtN
43	payment	3	3	3	1	1	42	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYbryim2gDXDcMgymHzbeXcNsdBWJsbcgoZAzYMGoBUSarTjRqz
44	payment	3	3	3	1	1	43	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZK6EeesGXnomxzJ5EtgFBW4AdK9AzreAo1x7qqqusEcpV8aSyo
45	payment	3	3	3	1	1	44	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZC6zNUmLGs3Z5mbobLsx4PgPhQA2nynvay82ALnAuE4sEirDWr
46	payment	3	3	3	1	1	45	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZeTYJr8Q24AgGgNBzthaWEx2mvVa9UimggnSL3nDa4bmoMgPpz
47	payment	3	3	3	1	1	46	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZcsgbKwfnoPuAQVQBQHp36Q5HFi94SYuNZyr36DnY22GhYRJks
48	payment	3	3	3	1	1	47	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZWscEWkajmCqafH5sZW1kEUcw8yt3A9b6w8UkFKotgSQc6hUaS
49	payment	3	3	3	1	1	48	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYhh1kD2LFafxsmxhsc3pwcs7GV1DhkoeuAo693hyLtubQEtLqt
50	payment	3	3	3	1	1	49	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYRQ5xKqxcKNm4d383LeF3APbpyqfBz49sgBaRQjGbESG9V6sVq
51	payment	3	3	3	1	1	50	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZAdu222W1MxPTkSnkVT53PZ4dkrf2aXHng8n5V29odRTRCA9sF
52	payment	3	3	3	1	1	51	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYf1zFEzq556ewBBQEU5Dq4Hd8AVSJQ7HMi4GXuEJuySYMCMvm7
53	payment	3	3	3	1	1	52	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaGYcBdfTwJGZ4at89Bpouep5jcAXJEq1myVbdPH4jaWsT3UNai
54	payment	3	3	3	1	1	53	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaGKQeDxYmR8YoQN2Biu7mSmViNTzR18Amv3r9PKzDhshvpaFCd
55	payment	3	3	3	1	1	54	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYfEqgVf94Fsf8pe9j5niMHNrLmJGrdphsMe4h3YBysymd6bvzg
56	payment	3	3	3	1	1	55	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZKbjsopqgxaYWdEAGg8AsEkwtNPCiyZ5kCUkeAwk2NmLQPGeaT
57	payment	3	3	3	1	1	56	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZw2fbVcHqJDiFdn6wW46Hrrq9wSku1HZCtVrN4zCG2LPDtbSsG
58	payment	3	3	3	1	1	57	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZhujssJ8S8apVvaayVzqoWcYrpynzMrervGoUDc9zoYZVK6pUy
59	payment	3	3	3	1	1	58	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYszGv7Vddi43MeJwQY8N5y9GibYKo3DQ86eYaFDPGGcn5NVxPL
60	payment	3	3	3	1	1	59	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZsjWVJo1mHHTAvr6EYXFmBHui1EGPgLgL3pgP5AMaSoq7VLgYc
61	payment	3	3	3	1	1	60	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZRdaDua4g6TBYmvGSZ4V29D86mDte86W3SE6Em4xL5JsCAsUKu
62	payment	3	3	3	1	1	61	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaE9VTMMSRKtRbmXgWKVEBDzfGFx8rCFuFzp4SC1S62oUSEKZRu
63	payment	3	3	3	1	1	62	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZcPAE3aeqKvP9K1Nykp3JJ7AHESBmzs83CPBFQE9L3jSbTrXmT
64	payment	3	3	3	1	1	63	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ8kZP5SMayx2vhq7QWT2XzvSxnBAusMp9EpvR7fRnsZccYbLWM
65	payment	3	3	3	1	1	64	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaAiuxATaeTkAsyja2avXXNE5ci2WSayTA1i25KNjaJje5QHpTM
66	payment	3	3	3	1	1	65	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZnj918deVYWJjpR7Aa7HNevmpH87V8RXbEZpjZovHCAd3BYS5M
\.


--
-- Name: balances_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.balances_id_seq', 142, true);


--
-- Name: blocks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.blocks_id_seq', 37, true);


--
-- Name: epoch_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.epoch_data_id_seq', 38, true);


--
-- Name: internal_commands_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.internal_commands_id_seq', 11, true);


--
-- Name: public_keys_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.public_keys_id_seq', 7, true);


--
-- Name: snarked_ledger_hashes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.snarked_ledger_hashes_id_seq', 1, true);


--
-- Name: timing_info_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.timing_info_id_seq', 6, true);


--
-- Name: user_commands_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_commands_id_seq', 66, true);


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

