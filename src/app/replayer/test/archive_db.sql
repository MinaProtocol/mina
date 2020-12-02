--
-- PostgreSQL database dump
--

-- Dumped from database version 10.15 (Ubuntu 10.15-0ubuntu0.18.04.1)
-- Dumped by pg_dump version 10.15 (Ubuntu 10.15-0ubuntu0.18.04.1)

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
-- Name: archive_db; Type: DATABASE; Schema: -; Owner: -
--

CREATE DATABASE archive_db WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';


\connect archive_db

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
-- Name: internal_command_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.internal_command_type AS ENUM (
    'fee_transfer_via_coinbase',
    'fee_transfer',
    'coinbase'
);


--
-- Name: user_command_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.user_command_status AS ENUM (
    'applied',
    'failed'
);


--
-- Name: user_command_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.user_command_type AS ENUM (
    'payment',
    'delegation',
    'create_token',
    'create_account',
    'mint_tokens'
);


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: blocks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blocks (
    id integer NOT NULL,
    state_hash text NOT NULL,
    parent_id integer NOT NULL,
    creator_id integer NOT NULL,
    block_winner_id integer NOT NULL,
    snarked_ledger_hash_id integer NOT NULL,
    staking_epoch_data_id integer NOT NULL,
    next_epoch_data_id integer NOT NULL,
    ledger_hash text NOT NULL,
    height bigint NOT NULL,
    global_slot bigint NOT NULL,
    global_slot_since_genesis bigint NOT NULL,
    "timestamp" bigint NOT NULL
);


--
-- Name: blocks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.blocks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: blocks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.blocks_id_seq OWNED BY public.blocks.id;


--
-- Name: blocks_internal_commands; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blocks_internal_commands (
    block_id integer NOT NULL,
    internal_command_id integer NOT NULL,
    sequence_no integer NOT NULL,
    secondary_sequence_no integer NOT NULL
);


--
-- Name: blocks_user_commands; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blocks_user_commands (
    block_id integer NOT NULL,
    user_command_id integer NOT NULL,
    sequence_no integer NOT NULL
);


--
-- Name: epoch_data; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.epoch_data (
    id integer NOT NULL,
    seed text NOT NULL,
    ledger_hash_id integer NOT NULL
);


--
-- Name: epoch_data_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.epoch_data_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: epoch_data_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.epoch_data_id_seq OWNED BY public.epoch_data.id;


--
-- Name: internal_commands; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.internal_commands (
    id integer NOT NULL,
    type public.internal_command_type NOT NULL,
    receiver_id integer NOT NULL,
    fee bigint NOT NULL,
    token bigint NOT NULL,
    hash text NOT NULL
);


--
-- Name: internal_commands_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.internal_commands_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: internal_commands_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.internal_commands_id_seq OWNED BY public.internal_commands.id;


--
-- Name: public_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.public_keys (
    id integer NOT NULL,
    value text NOT NULL
);


--
-- Name: public_keys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.public_keys_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: public_keys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.public_keys_id_seq OWNED BY public.public_keys.id;


--
-- Name: snarked_ledger_hashes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.snarked_ledger_hashes (
    id integer NOT NULL,
    value text NOT NULL
);


--
-- Name: snarked_ledger_hashes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.snarked_ledger_hashes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: snarked_ledger_hashes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.snarked_ledger_hashes_id_seq OWNED BY public.snarked_ledger_hashes.id;


--
-- Name: user_commands; Type: TABLE; Schema: public; Owner: -
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
    hash text NOT NULL,
    status public.user_command_status,
    failure_reason text,
    fee_payer_account_creation_fee_paid bigint,
    receiver_account_creation_fee_paid bigint,
    created_token bigint
);


--
-- Name: user_commands_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_commands_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_commands_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_commands_id_seq OWNED BY public.user_commands.id;


--
-- Name: blocks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks ALTER COLUMN id SET DEFAULT nextval('public.blocks_id_seq'::regclass);


--
-- Name: epoch_data id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.epoch_data ALTER COLUMN id SET DEFAULT nextval('public.epoch_data_id_seq'::regclass);


--
-- Name: internal_commands id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.internal_commands ALTER COLUMN id SET DEFAULT nextval('public.internal_commands_id_seq'::regclass);


--
-- Name: public_keys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_keys ALTER COLUMN id SET DEFAULT nextval('public.public_keys_id_seq'::regclass);


--
-- Name: snarked_ledger_hashes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snarked_ledger_hashes ALTER COLUMN id SET DEFAULT nextval('public.snarked_ledger_hashes_id_seq'::regclass);


--
-- Name: user_commands id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_commands ALTER COLUMN id SET DEFAULT nextval('public.user_commands_id_seq'::regclass);


--
-- Data for Name: blocks; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.blocks (id, state_hash, parent_id, creator_id, block_winner_id, snarked_ledger_hash_id, staking_epoch_data_id, next_epoch_data_id, ledger_hash, height, global_slot, global_slot_since_genesis, "timestamp") FROM stdin;
1	3NL52BwYWhu6oHPY5YAWsUmFtcuCJJ7BCifUxgq2Wo9CwNdgiedA	1	1	1	1	1	2	jxg7fB9SZMZLcuhLfHMwGaPFUAn3Bg2MNadrFckhwHqT371AUvL	1	0	0	0
2	3NKhj9ecghbMcEnxFqoP37MoSNQVzqRKSwLmyZ9jmQUobXUSKe92	1	2	2	1	1	3	jxxQEzqG2gMbUMMd5aA524RDae5gdbyu4HxBbBe8LP4WtDafPQe	2	2	2	1548878406000
3	3NLcFWaAcMd2Wi4EPKSLaYwWVALfi3PTSt9rj5ZN6EkY2L4zfwmz	2	2	2	1	1	4	jx1XsErm9KVpy9rxs4VEEsNNp3FSAjMctkGKkHkZuuvo9DTUQS8	3	4	4	1548878412000
4	3NL92xsoavCeyBEebcVxX3R1HVKyqFsquqpG426HvJQ97srtNhQJ	3	2	2	1	1	5	jwpwdTERXHyna5pjvqQZhj8PSEF89rsMAxuqUJep2JxpEvYn52a	4	5	5	1548878415000
5	3NLFESjpGDRM9UjH5otuHFMmXcHay97VyFYA5UKkBBTajPYqKkUw	4	2	2	1	1	6	jwZG2JKgeNfxh67r9T9PtSJLFMterqqkvWEaKPY5duTiqNqZHvV	5	6	6	1548878418000
6	3NKoyQ98PcdhHUQ39wtNXRhTBJxLGA5VMFU12dbwYDS7hYd9jvxv	5	2	2	1	1	7	jwcLxMGnhzosKjixguE7jwqE7KQXJTMgQKxcH8FVR1D3MkXuVGZ	6	7	7	1548878421000
7	3NLdRcAcoFBepSiECykWHo2H8FwPxgXmRfcBMsJNnVHCEDC8PL5G	6	2	2	1	1	8	jxmFMDpSyBkbwGCK1PaaJxr71EZT3uDBTczVMbBo1XXAXvU9xvq	7	8	8	1548878424000
8	3NLnPESbxskPH18FXGKQAw3qXY2YXhyLzqLg9ZwSiVHhSvsiwTNh	7	2	2	1	1	9	jwmTRNeTX7GyySwERu6mnHUeWEJRyn3eaTsu1U6CSV1rgcSytXF	8	10	10	1548878430000
9	3NLn8ZnWTMdyGZ1wq1stNQzb2qGxsv1QD5penPK7TCLhMXb6EsjZ	8	2	2	1	1	10	jwieVstTyNaCfNmmRpDHqtLJQx5HWphRiGLExEN4n5H2Kg4C3Yg	9	11	11	1548878433000
10	3NLeo3PAv3tug9YhjC16bSXpxCBYSxfaPvU79jwCA4R3XwT5rdLz	9	2	2	1	1	11	jxMCYmfSomzhVw4hM2XfGXE86HmWDa8qQ2Y691PkgxviX52KpeE	10	13	13	1548878439000
11	3NLArBTEsrKPNwwphP7QxotofwxQoU323ZkeM8UXYg8ruFTPtHfy	10	2	2	1	1	12	jx95ismayhhh8McwN2Vi7jP6cPQFbxNWg1XfdjcxWBBQceD9VvU	11	15	15	1548878445000
12	3NLDpYK8BjwAk37Wdg8Cj8SCZMdpBgB2gH41rvPhmBADxVwZEWm3	11	2	2	1	1	13	jwTpcTm6MjAXcRiKFWV97XoMTw7DoMmQghSFxNeAcrdEmZpoYzP	12	17	17	1548878451000
13	3NKxSuUj3RFec5DniVR3nEM5ShjyPoDG1gZSpTij7kc2kaQsnYy8	12	2	2	1	1	14	jwSDCVeSpb2KLXNyX9Km3zQG17ZeGNMAQVwWvZRpuNSVCGA61JG	13	18	18	1548878454000
14	3NLDUiwj8CzEGDQxwbpiw9d5rdj38FgE66fJopCUPr8u2FwKKKsF	13	2	2	1	1	15	jwL76fCD4vbbChvfLvesxZNBAN5SmQrkzvXGcDDSJLyfXX1wepc	14	20	20	1548878460000
15	3NLRQA7C6c8H2czx1Jux2JDRqMBkNeJYvVgEd44JB5DZg4K5jHuG	14	2	2	1	1	16	jw76PsczpJFUQCAD2yDzg32qTBKyBidkm58BwLEY2x6Smx73Vc6	15	22	22	1548878466000
16	3NKRqU3zxbGFJrdKYqjCWqGcRdvLrm9JMoCX9rzHFvY7NDZrxpfB	15	2	2	1	1	17	jwZK74Sr8FGmC9m3GxijpJtm8ubjCFoFSTUHcbbrzfJaXnB5pbL	16	24	24	1548878472000
17	3NKjmK8nwYzDxqamzPmoe9XvpMhDSr5rtVQpVEvSF9nRQhE7SpWY	16	2	2	1	1	18	jwUpzyj6E98j8BY9xE4sxWh3AwRfrU9bNxgN6dkqHF5v2BJ1uhG	17	25	25	1548878475000
18	3NKypJnRBTmwt5HqivDGDhQJkpbkqzTK7jNuFEDH4h6LQKo9tqrn	17	2	2	1	1	19	jxHannPaR8korqq9aEBqgTf4y3JijN45mdJiVtVAXuFimpfrk3m	18	27	27	1548878481000
19	3NKscLDnVuXLkS9rmX9NQmgo3yzuK3aoYVrnWoYHAkmnMQwFUgoq	18	2	2	1	1	20	jwPBtYVqpPi6RxYsj1T6KhGf8XScZC3EKDNkxQqyXwY2wm1oUeb	19	28	28	1548878484000
20	3NLEeDdq4sVXBoAEFNE4PFZq6qfxApJgVgPrGJeBMEUdMQCeN8FE	19	2	2	1	1	21	jx1zuDFGVPGkrQ6EphF6oKSvyg6HWV1vpooxwtdejBHXfFdZXxR	20	30	30	1548878490000
21	3NK6Cta3fQ7fRjvLyWxyh6hes3rvw4wuYHiAMA9onR2X45pV4i3r	20	2	2	1	1	22	jxtgV9cerTkigzDeBag88fjgPaKC6vquDTBiTL7GgMeaDRZYi1g	21	31	31	1548878493000
22	3NLZjisCxah4w7wvSqsfP2SGvcS7r3syU4EuUqm1BrVSk4ZzezwW	21	2	2	1	1	23	jwANQmmb4tqJxoUW3eYSb2EEYNj3X5T8oMQPmBVhZgHigT3ugTB	22	32	32	1548878496000
23	3NLJFD5vE1oRHC6qVzcDiPBUqTsiH82pCtWZ1QQ6bUeeQ6qeJnc7	22	2	2	1	1	24	jwrSgLCgFWb1N431Zbqup8nckK3hEjqNMCu4pH4y5qnehdXbAYs	23	34	34	1548878502000
24	3NLsHdtsJZq9wSc4Mw7wreyig1qr84YoVfjUho8UDpDsLq7Xngwe	23	2	2	1	1	25	jx3QSMdUTwwK7z19Kj5oiGVbTufzMG1cFRic2d58W5xZ5t4xSQp	24	35	35	1548878505000
25	3NKDVmzQxgiSsiHru8T5bd6zXdKbT8prMzEdeydxwLwvtRiJ4ePn	24	2	2	1	1	26	jwQDztchuHBkGxTt9v3gfZRVnYaRu6wEpFLoFmJe8fkJFajrSwj	25	36	36	1548878508000
26	3NLuPY2eQso6taErHarXnQjqCf5scWW4hkJdrgTGjELiLuvFXcnS	25	2	2	1	1	27	jxvgL8WdaR2xjCzuo5gy4u1JSgCi6ak3NUCVuDgtXJ6fzahpx1z	26	37	37	1548878511000
27	3NLBzpdiw11ySqH42fQNa7pPEzPMYiwUPRNqyUKAUSamZzhe2K6L	26	2	2	1	1	28	jxfDgQeyX2u9zohDMrTySqbuiMvP6uN2kijnTovegQ7hzLyB4ny	27	39	39	1548878517000
28	3NL2RN1KxavB4wZnGzojtkz4vNUFR69Lzd1NoxTcio4hvnYydYgf	27	2	2	1	1	29	jwGXezWbadqb8j3kjy3VydM5cmB7aFwUHL1p5xeLVV3StUb9NsR	28	40	40	1548878520000
29	3NLvgzwjq6Z93YQUPA7VtUBVCmiMzKqiCUm4ZywQxDp1RhWw7b1x	28	2	2	1	1	30	jwMSkLJKaD8sLfnQaDTRDS5TFS6M7MuBG99fCdZyJujGayKUU43	29	41	41	1548878523000
30	3NKg7qEebKFi4U4Y9rQoii79heDg4UU8DELkp2PUt8Ae32GAiHFy	29	2	2	1	1	31	jwErmjxoZNqAR7ij1tWqph1e2MxbzftJC2YuTC48WGXPYtxKtXn	30	42	42	1548878526000
31	3NLCGBTmFQMbpK5kuDWbWdZDvq6Qw585MaQhkSTyvVUhW1Vj1LUu	30	2	2	1	1	32	jxNqtKdgjp2mmnXVto5rhKXPgbaCFB7mt3AEMtucjqqvE4ujv8k	31	43	43	1548878529000
32	3NKtdGYQm1W31cHKczrDPXPvyRKdEWQDq1nyGujRhFB381xiEkoJ	31	2	2	1	1	33	jwysW2ggeNyTrXVrfueeVhpKAHU9GNJzBmCnKNDuwRHHeXUrnar	32	44	44	1548878532000
33	3NKojQBG3XTcqRJp2SkTvEjjxp8VK3ZQGmxrfFpU2bxy24oZj37U	32	2	2	1	1	34	jwMzRvdc4xMhWbaJ7MSdLw5NmCdqFd2gt9zkvqiUdiR5yCMuqq9	33	47	47	1548878541000
34	3NLxscktrigJC5GQgMEhEw2ps2JhTYnjetr4pejEsY5xeAEUzBrr	33	2	2	1	1	35	jwuEp2FBeABuc1Vjq4SFLqZFsjDKjGrDK7JTkoFxKUQqXQRnd5L	34	48	48	1548878544000
35	3NKC7wnnAtzu29wbQC9LX4mfNLwdWhiNMhtZ6NiqewDpViXPpPsB	34	2	2	1	1	36	jxoQ1oAHdPukVaEGwdALAccKEe7W3NeJs44rZzz6FNiWvR7nd1s	35	49	49	1548878547000
36	3NKW2XwmkDCjxH8R1WDfiNshT1nqan6nruz23zeBAdna61pupNgC	35	2	2	1	1	37	jwk5bezV6DAFHvmw8MKmNNe4RXzNX9PfGQ4ujsZYDniN77NURYY	36	51	51	1548878553000
37	3NL4fSw2Ji6LYowGqVZkMQBghnnKYvAk7jKUXh2WuAnz3k8S9sRF	36	2	2	1	1	38	jwMmow76DmrHzxE8SsQ8be1VKk4kAyc8Tt5rM6ji3f3aUMkEH8j	37	53	53	1548878559000
38	3NLwnSEvrNFkkTVUe9Mk63p6HYUrS7jDG2fCqaXoYjTJPxpaFFbe	37	2	2	1	1	39	jwbU24QbvDVceCH2ohjPNpm5S6JHJPUQCBgTmH5G9436eHvaMmS	38	55	55	1548878565000
39	3NKxTFykRh7LP7uN9Yiuiw84YtvFFr7pmdvc8U2s3msbWK4rTXXm	38	2	2	1	1	40	jy1WKHXGijJdrgKdafpyTk9kjvEgi7ctGmhHcibDUcQ2a6drgGx	39	56	56	1548878568000
40	3NLdiHZbWrTqjzCarDLnQ9qg14z9RCBi341YBDKc63gLQTgHKMjR	39	2	2	1	1	41	jxL3rFiizMjsEcZNCyzAoTzxBQoMYvcNgZHMcWeifoRhpcARdYt	40	57	57	1548878571000
41	3NKjxPKRZvs7k8rDk39K7acGa7Yo8xjdxSqy2UZqNqcP3wUe5rf8	40	2	2	1	1	42	jwcxDaiWrfciaCzE929RxznWa5e4gxhQ7PC1kBsjXxekuhUejgZ	41	59	59	1548878577000
42	3NLgdwVunrY8tTVR7rg36z1Zw2eLGRhPg9icNwYqjw71YBe7eaNV	41	2	2	1	1	43	jxdV4tzscLe3Ae3i7ULPtArJW1g5igFP1Tg1MBxx8PVP9tuc2pu	42	60	60	1548878580000
43	3NKvwN7s5xauQM4mtqeCneP1BJ1b7AuL8gVdMdt3qYWsFpPdsTg5	42	2	2	1	1	44	jwaY4wkuqZo361Q5XtQ2ernvdgtUEnNezojJtiYwYmWhjNe1w4D	43	61	61	1548878583000
44	3NKsT2krLCC8up3D67feQrrprDS7c1tftsTWfuGWwxTqVimYz3pg	43	2	2	1	1	45	jxniGCVarJpAkedt8xT4JnkDdM6WbqiHxT68RZnUqSACyPgCLVm	44	62	62	1548878586000
45	3NL5ZPf55khPH9YdZActKf8za4pRrw3K56CmbGpLkiuEDwDRCHHe	44	2	2	1	1	46	jw8vQ16W8GxeTvzJP2e6uY6vzSfUwyMB7e4XbUDvpBd5jx7Xnem	45	64	64	1548878592000
46	3NKEc4cgqD48TPCBbsLBWTXtfdHeyC1jJd3WVSJscrAK9zhhncsa	45	2	2	1	1	47	jwJXP6vwKCvSdZtY7nWcUNbU5cCVL8nn29vbq3wSLxTtV3biSnc	46	65	65	1548878595000
47	3NLmLrXGBhWozniQGGhCF2ccsmoCYyo9EYd9pdunuEALdWjg7Xiy	46	2	2	1	1	48	jxBojWVcJSpvJtvWotzepdLeqaybzm18HjU2EQXwtr6kbG8jotX	47	68	68	1548878604000
48	3NL4CbP3G6912PqegGnGF35iQCEddmq35dJ3UMxmXnvt4rfju2pg	47	2	2	1	1	49	jxgkePLmiG32y6toe9habVkTZHpfA6Vw9kztZjLpM3R4C2fQuJG	48	70	70	1548878610000
49	3NLAX6NMPY6UqYL6nbyAxggLs1UtefuoTywGgwnTDdWQrBbqmsGB	48	2	2	1	1	50	jx7q55iTTWaGdAXgk69gQuVH5j9iiBVDukehdARFfRk3iwh9kEP	49	73	73	1548878619000
50	3NLEaRoSyiQ4mHz4Yj2SXRJ5AzKq18XrkXd2x8oYgHbHt3FnAb2F	49	2	2	1	1	51	jwbUpuPT6ZJKfSwaqmPWPPzEEXpaPsqo9iVRPLBREma61tEpymp	50	74	74	1548878622000
51	3NLGFMJgbZSN1ouEpu6bEfZenwdKuT4Rj5YJWj7f1MjC5nCxqsRR	50	2	2	1	1	52	jw9ZgqzWFAK8esxd16P3SMFeoZCtSNLu3iNgSwGbXYXpiKdtUru	51	75	75	1548878625000
52	3NKSt8UQrkeyAwN1f2sNwr7SoXBoWHiSWkMw45gTHm5ikZCVEDYU	51	2	2	1	1	53	jwVT1T8njUAHQ5rzwdEKt67ixjLgtBHzuR1MX5yN3YVd9VLubJG	52	76	76	1548878628000
53	3NLFe7YWVDokgHNRWsmUXE49UkYea4TqmVnRbNyNf2vin9DtZdfe	52	2	2	1	1	54	jxUoU2KWVYgH6o4agbTEgGTPFb9noie6BgrwC9YAVrK1WtGUFCR	53	78	78	1548878634000
54	3NL2pbhEeXkALXJNeRCtw3YcM3tLjMRpgAM86y1DkmUg5Qo5NUtd	53	2	2	1	1	55	jwSmckKjd6fpFMoVQbtQ81FhBsdNNhK4eSDsm3bBFFVBfWduVEV	54	79	79	1548878637000
55	3NKmAvmiQpzSStLDBUrxLWHeLVJbA53GceGoRYwfS3d2NZqJthoT	54	2	2	1	1	56	jxTaDcFcvGuBjJQetTHZNA9asprGCzvt6a49RV8CvRaqnA5EWjc	55	80	80	1548878640000
56	3NKsCs2d9xSaaqiWcoutR57Gf4X8wYdjYuJqKkLN4fGkZVQ48JHz	55	2	2	1	1	57	jwWrSq9Uw8rGTN5v3f26EsPxKktT6HRrPNFgqUwAAj4yHaKKMgn	56	81	81	1548878643000
57	3NLSpfWnnMz8xxZJWdS3YdaVMhgVFQhe1hbMS6EJbzNPefcwaPLM	56	2	2	1	1	58	jxN7QQetR4nDWFifmT6cVRZRPgzb9bzAFbGRfSBvyoV56F6ceJ6	57	82	82	1548878646000
58	3NKBXZtsLte5cXCZJqdm537wv5yG4fwpFnXvP3XTp5uAoqD2tc9k	57	2	2	1	1	59	jxGCKbw316y2mypwqCtSUgCadrnkZ9bvYWT8LX29BFrrKmucmBf	58	84	84	1548878652000
59	3NKy71xX1NTNqRovv8JWZnyLt9YEmgcqTp1TCsBaBYTnwwrVSgwz	58	2	2	1	1	60	jxP2mtHqiphRXcdhQmMFK8p8SzNjxgzWLJiDaXSVHzxg1a8JMPL	59	86	86	1548878658000
60	3NLL7wgaaFwXgnHRc32ScmCGrJTzwDh5WiC6H6W6pv7tonDj6p9G	59	2	2	1	1	61	jwdXvnJPG8zgYLv5Erk2X6SVMx69RU6UmYoNBzAm953zb7pGKrJ	60	89	89	1548878667000
61	3NKnKm64KLuGmAVYit4b4b4JDN2V4EXhZjEMKZ9UY1DAoXx7u1Hy	60	2	2	1	1	62	jxcLfQ2cGsj9SviA9Eyp8gFKYiogbd3GXWDsNKhm6Kp3bV3zQcF	61	90	90	1548878670000
62	3NLhaFEy8YfGBUVtxheJ5P7uRoKb7XcQ5cV9FbF922Dj6qPHg1pA	61	2	2	1	1	63	jwNLQuvk1CsVcZEJA8iLPn2VTUN8iHJbK3dPnME2SNosdumF1pe	62	91	91	1548878673000
63	3NKHujfNnP61mN7Swkx8DkHvbmxHiFFuNgJZUBX2HR3AdFcwxVqG	62	2	2	1	1	64	jwvgX3SN63Jq6F7LFjj5U6e7Ro9phhSUMUYUFzm1hXxpsw4FUs4	63	92	92	1548878676000
64	3NKmBigBYBUAJxUMtprwNTsM2KUcevWDqbVammNqXAVFooLWGABR	63	2	2	1	1	65	jxSzDm1VRteLXaow1etPqdxk3cMtEdS9y2htmjatu33mQu3Wdc9	64	93	93	1548878679000
65	3NLgteNwBE3fQHRkRs6ftPgzswY99VXRXkCHZxwdwxNc9qLGXMRG	64	2	2	1	1	66	jxiNAkindWbPMHnPCsxHdiBujtNHSoGoLyXrHQJDtwb1aqfX73m	65	94	94	1548878682000
66	3NLkkDBSkdMfgMGmDbfeerd6X4ktxbntYVUkCMb7eizhzQ6rLeoq	65	2	2	1	1	67	jwP7nhCGPwAg7kbn1uyMEMoPvzw9eFxqZ3K8h36Rp9d5ebrAgLA	66	96	96	1548878688000
67	3NKfByJWwaGHm1tMuBTVv7dCKFz9zutyvuZdrP4EoNfRhNyJC85F	66	2	2	1	1	68	jxTPrSS1wLZDUZ3p7A67xWLDHG8raZJGyuex8LsbcFUvAaz29vY	67	97	97	1548878691000
68	3NKAiMnZ7ZmRFc9hxyinKkS9SophqUi6cPxrHntwNYwGbM3Kbu9f	67	2	2	1	1	69	jxAVFzDbyeWH2EFc6V7RyeeHKShE38GZMLZUtczHWXmXBHmYCZ8	68	98	98	1548878694000
69	3NL3aZD4xD57xTHK3bxkEARGxnvZMzv1oek8CP9CB75RgX9jPxkq	68	2	2	1	1	70	jx4FV7vNtNEWzQTCUb88sAQ6EbAyRdw3Sh6EycfhZkHWxbzZaAV	69	99	99	1548878697000
70	3NKxUqE5FvnZksA8n9npQGyz6cocdHTVX18zeMPAi4p9XknnhtaG	69	2	2	1	1	71	jxvP61xhtBnv2hSt3ZP6f6epZBLhUqwsWqJK22WFLcQ696xwWyN	70	100	100	1548878700000
71	3NKBtJzfrxsLLJ9yaJM5RgNd1cV2ZAjCHNrdykCT8oK37Vj33onQ	70	2	2	1	1	72	jx9oCWBnQt7nvGfD4AQP1wa7eRDpb16cwTLHkTp4oZYfwnqzNiS	71	101	101	1548878703000
72	3NL8xcD3AoUfHYqiWBH9V7MW3dbwTvJ7vC1g4hAjcsyZixQxWZj7	71	2	2	1	1	73	jx9LPoud1CJ7pvYMLTpi4113Wf93u2qCb5PetCWctEELTzpwjVv	72	102	102	1548878706000
73	3NKN6aB2kYDFeUhEFiSthjZfCXXDGQSW3DLTG8T8qgeiyo2dBsV1	72	2	2	1	1	74	jwEAq935VMZdWjBcynXcJjFS5iD72ecF7CMYEQuUEHMq1Wu3hMW	73	103	103	1548878709000
74	3NKR9eQSf8VAyHMjRsdjmDPbZ9EPF9exdzc6TFbzZWYodhkWG3sZ	73	2	2	1	1	75	jwppW7cEcbbfNu6odh1gfs7q6WshkNbf1eMrohQSMCUkt9ucrjD	74	104	104	1548878712000
75	3NKQ3CK7Dcb3WtjWDAsKYCRoGYSJ1nqvx6M1kjoDvbqASizkvEMS	74	2	2	1	1	76	jxJYwvkoTijfL93AR6vn1THkMaYytVJ2GX2TJL2Ygkxf3sVkNgj	75	105	105	1548878715000
76	3NKtzFqf1mTVnTVf7v1YvKM9Mh8CLcENKZzx6S1vWPDKcsucqovx	75	2	2	1	1	77	jwWfWRQmNET7USywX7d7kL9DqTMyZwiox1TVF2QkZSc8LLJkZMW	76	106	106	1548878718000
77	3NKdAizaELjRaU9MnaLSoQFWzZZ7qZyrqHr1cpErksX9N7EqSzxe	76	2	2	1	1	78	jxrPAk7AqBMGZMCuu3kT8LdCr4iuAYAVVTnsyT8ScVC5NJ9VWud	77	109	109	1548878727000
78	3NLSskbSh786rxaUFjRSPV83hvLEciW1AVKhBskTp6B19QkcJsTA	77	2	2	1	1	79	jw8Fu23Lq8sbPK7fct5vw6E8vDLRV4HpXnaaare5CrwiBm4Nuqv	78	110	110	1548878730000
79	3NLuLSuLQnQj34irrJVgGZnRnJCvRx84JHSWGdw8FquzXd5kGj8W	78	2	2	1	1	80	jwqKDGfNXcKZzrCYQNorCCcuPEeV7tgv13nmP6mndDZNXg54GEe	79	111	111	1548878733000
80	3NKYKxkBEeoMTJcRh2kzxY2xUnzMagebH3MAL7Y5F3xWMkwVK4ab	79	2	2	1	1	81	jwR38TBdc4zTdtxd9MqFeQUsKDif1S6atkfTDysfMMjCMmsD3UQ	80	113	113	1548878739000
81	3NLAe1nbiVib25a6PevFtJmSV173mWzLhSTY5RH3Er6UcrJ2Sre9	80	2	2	1	1	82	jxEqtG8akJwxGcP2TeLUTbGJJPEUQGC3uWucLi9YwruT21y7NV8	81	114	114	1548878742000
82	3NL73xJMQUcsKjaenL5UXMA9YaboorwuN2q7Eqxyb1MmnHrJHcGB	81	2	2	1	1	83	jwdaLuvtTpPejwZ7wRK7ks21AvRErQRvuYv9YyE18jmW7fMWSEC	82	115	115	1548878745000
83	3NLNyQBzRBokFdpgm4wbGycasDuAY55VpSJjKmrChSUAjbSRZgkE	82	2	2	2	1	84	jy1D3mZzYunFrAAVGAhaCkEB19gvLhAqtvCFa2BADu5MxGqEr7s	83	117	117	1548878751000
84	3NKA3yH1DyeKwSNdeBVuwcqJwD5Bd5at2ovskLMtbr4rvsgyc8sy	83	2	2	2	1	85	jwswDZ8r6rWrUD86DxSgzYhu7AWHXnmh5kFH8btLrTKYJzjsgqi	84	119	119	1548878757000
85	3NKjKETL2go9xu5LfcHo1gfFfZ3AJSja4pMBmNL5UVCpryHuYVLU	84	2	2	2	1	86	jxqQ2S9nKJJxdKqcRSM7qHma9Xz3E3UaW5jV6Exf6QdUqgjKqi5	85	120	120	1548878760000
86	3NLKhbwaA163aPARPjh3cDXRWmrGb5PtuzWcDB4eBnD2By1kWf95	85	2	2	2	1	87	jwHxH9NPHk5C6g492GEhPPg7ADDoohKiLyYkEuAucfbwNcdBHDR	86	121	121	1548878763000
87	3NKuu2PGibV36ibcdfEtrnZnh1rEZmGLpdYHZAidRkiGC4ZVmvPs	86	2	2	2	1	88	jxD8z4PzF1uAUMmrezUMheAr87dpVECS2Vn2BsvZEKzLWP55N8M	87	122	122	1548878766000
88	3NLQGAyXSkH4ycTF8m6emnujTHBUys93TQdBXiTsd23Lwbof1oGq	87	2	2	2	1	89	jx2fByu54PHUh5mh1WmNeMREZx8TEDYzA4n4NBw64KcksLb16vg	88	123	123	1548878769000
89	3NLjxnY7aHGArshbhuqH7FDsiByP6eP3GMbTk1QKjjZC6Syw53b3	88	2	2	2	1	90	jxpjKY6AfaDuAEDcbZBs3G1GGEvZzaJ51fvWCBhubHJfXXDUdmv	89	124	124	1548878772000
90	3NLNJWjJFyiuEK7Rwm8y6HnmjPTmsGX2w94iiLqVnudw1dum5t93	89	2	2	2	1	91	jxAk4f6dDBXEYrdya87Eeb9XdBXpveu9VASFArnRKb7NFK7zGsr	90	125	125	1548878775000
91	3NKpmShRZqDzwZkgMNt6QztSPt8Gg2QuJPyLJdYZ1e62UmbovLHX	90	2	2	3	1	92	jxCzUKh5zGSZSW12BkVEw7mrXuMLkr64oyDZ2cfvo4A5Fs7s2gc	91	126	126	1548878778000
92	3NKmAvHqSW46aahyhwRcw9wxVAcLx1eJGhH8Ys5sH13ERNcN2StQ	91	2	2	3	1	93	jxB4VxD1ftsUsSbbD4T7PafkXdXGybW4rfJ8YTDsoZ6YT8DDutR	92	127	127	1548878781000
93	3NK3mY9ReTYTobdjqEm2DmrdqPg74UVupSCsV2ghjQHCxvVCgpeL	92	2	2	3	1	94	jwa7RqGf4m4MVCZf1nMjZxZsjEKGadkbZUhbjL1YijhvemNpVaf	93	128	128	1548878784000
94	3NK4JiiRxHrWEr81CcdPfLDRf9WBJtsLwiBSvs6DarBmQNN3F69a	93	2	2	3	1	95	jwVnjWUXFsDhEjJkGPdbMdNsHV88Nn6Ty2W8z7SvWnqeUQbY7mY	94	130	130	1548878790000
95	3NKa7YBMDavht7kqh2jMxC4RrGK6bjmcbp8dxLZABZnDJ7cTznpM	94	2	2	3	1	96	jwr9wH9qTp2fUkBJa478TjUtvqCB8eoU2zFU5sz6f3GZJbZPKqB	95	131	131	1548878793000
96	3NKhVduSJxjD2Frch3GNbJParYc6gtucNEdUNRhkAthSBDJRkAqG	95	2	2	3	1	97	jxCHcZ1niQ4xfws4d3vXicXi143d15eGp92E4acqJuEuNwtLcen	96	132	132	1548878796000
97	3NLU2eNaQyVxUAQynFvaRdvyLmy5R14LGZHq3wBedgFZjPjJQx7S	96	2	2	3	1	98	jx6Nf2cU7GNxJRGfCKjSa8mxJVUEzxnJuzzvo1rnyr48gTU4AXE	97	133	133	1548878799000
98	3NLFHdFvVLfgnupQFs9cwLCgasx2MBVHcbYqBGXrNr6PgufHXpC8	97	2	2	3	1	99	jxfRagq87fkrERi8xV9UsnNr9htuKkz8GkeszvRCK8GgUNr6DTb	98	134	134	1548878802000
99	3NLGMsQEmBnueZx66e5awVMQ3VCpjsbP96H6KhB9Jvv7p6PsdwqC	98	2	2	4	1	100	jxRLGrLpLNVExepmBvJWW5CZJa3vfEz4cWeGFybCU6kCuy2on47	99	135	135	1548878805000
100	3NLWvRmFmqm2Na6u4M5iPdMvYNkogKqwRqFWCSwVkGdjCV9ijkCW	99	2	2	4	1	101	jwnhzEqhu8SSXU5NQVaZZ1fEQXYbiFhE2zjF7WUavpSksEgD6vE	100	136	136	1548878808000
101	3NLCjJ8PyZCMmLHuZXgUThguzMkjkGuzQfVJSYeizBqxNhguojak	100	2	2	4	1	102	jx77CfVgftXQjCjArGZ1aNnSmyXiJ4dMcgBZBeeW1mpqkeVHqYZ	101	137	137	1548878811000
102	3NLBfKwPka2mpW643GnijCMNuVuaKMCUj5WdGCL5qNtzhB1pvdLL	101	2	2	4	1	103	jwCbygamLdg5fR74PPCmAvtQb4MgS1gPA7PyMLuSfs25uGQvXgA	102	138	138	1548878814000
103	3NLMQ4ZMytK1iiDoewR5EB1gYAyGwy6DR198upe2SFBThevdPfTe	102	2	2	4	1	104	jwE438uEwcHAmEpheYPvi1EBVT8LsHY3SfZjGajZT4WfxF3JNMT	103	139	139	1548878817000
104	3NKRdgpXqJSvrBsKcaocpQDNWg8jsT1RLrAmBxk9rw8EDRum8gFL	103	2	2	4	1	105	jxBz5XheCR3KBCDJDjYHXhsF3K6znWMHSyuJsGPUTFGuncs7cmY	104	140	140	1548878820000
105	3NKaQLiAYepqzdGVnSQMXKVqDRWVVALVWwfvPH2DDZkU6v3vvQP1	104	2	2	4	1	106	jwryiqe2B8sYArkuVxEk3RBjvnLdjLDfgz46GKyWYCJegQxerhr	105	141	141	1548878823000
106	3NLERFcGPKqzVt4PWDxU4R6Cf6GWJ4ygRJW4FUCHcRnBYoD47PEB	105	2	2	4	1	107	jxhzZ1deG7VUJo69TFdHFv6Ashx9x619fmfnygsGBMqXfhq7jtL	106	142	142	1548878826000
107	3NLHTdA1XgQfcYtAWMiPQVoWzyBdbB1836Q3UBDyR3cz1Rqo2WPu	106	2	2	5	1	108	jwZHL6AbGc4w6oKb76dSmm8xD6PePZJ9rbup6LaMTz5gnp9wW8a	107	143	143	1548878829000
108	3NKThS7vJWtu56yQPveCETYgfCTJmZfTdKkij2JLBXN1PbwguNUV	107	2	2	5	1	109	jxpPj4ZQeNqVXeay4NH5a3zrPMhsu69FFqWoVbRFF7r3LEjQtha	108	144	144	1548878832000
109	3NL5Wo8QoJE28h2byPHRDgGdjRTkuZsXbZNYJ6AvJmkHUpjDhoEK	108	2	2	5	1	110	jxduKTYj89WNwh9XH6RPqaAxnDuQsstck2VmR1B9n4DkpPeXBBo	109	148	148	1548878844000
110	3NKDxVqGwpufsCnWeikjNrFKP3woa3oxHsPVtxBHT7KUtmJJjKie	109	2	2	5	1	111	jwsmHGJP4bab8HsQxNZKbNuzns468TvYum2qrDAYcxaFonSw9mG	110	149	149	1548878847000
111	3NKjj7vynR7nwTmR83tkzrZqM3kVvxMqKs43QT3HeitNxvTkcMho	110	2	2	5	1	112	jxepAjE3KnWfquggUVY2WQMc7JxQf2WkSAdmZvn2gd2AM5dTq12	111	150	150	1548878850000
112	3NLjdsLVPECuq44dp9dAaTuFmVUaTQ6W8vXuF7ygvuX5eFebYqac	111	2	2	5	1	113	jwE4GvY8sAZyzwK6Sks5sKFGRTADjZDLafuLnbeEhNPQdyaQmYw	112	151	151	1548878853000
113	3NLc4cQXwaAbV54PbKC86a39dvgW3vmF4YDwfCNQsgj8PUJx2hqD	112	2	2	5	1	114	jw8fJ2Ws7Hy6AF61eij9JMnJ9545DCUgFrCqjpG7o3feFtCCZcw	113	153	153	1548878859000
114	3NKR61Vr2rjPZgkXbNPPXQAYifAPPTVFQqbEUdYsf7jY7ViefZkg	113	2	2	5	1	115	jx1yU1DREWJ26qSCD4CDkUGBzJyC8njTz1AHBNPuwxwGMvbY1ue	114	154	154	1548878862000
115	3NKkWvMMcdJkXgEqMDt7nGcJvGESDfqMDDtfkCimw1QRSm1ucnqw	114	2	2	6	1	116	jx7GA7rxQ8qLwNbZXmxGU7p4La4mwqGmvdHfJJa4JgWSeABessn	115	156	156	1548878868000
116	3NLbScYUevqiZsYrZfRAWVZCEnmz5wCQQaPFuV5xHJzrwTEP6wRw	115	2	2	6	1	117	jx47UgEdRv4hLiehQ5VLRV9Jip1ZiYV8RJ1u8k9fEYw9jcsdZ3t	116	158	158	1548878874000
117	3NLGdfPoxEdN1pRBxykX1Lt3eB2rieqVdeeexjvbQKxbnvt468YW	116	2	2	6	1	118	jwag6fABavdD2D5U6RjiV8sSBUZmvBEkjKLe9axZ21Kmeqt1o5u	117	161	161	1548878883000
118	3NKuXWvtz3j7yAr3YY1Ncd8NKCWTwHrwq2FZTj3U8brfEdJHatGE	117	2	2	6	1	119	jwPpSteTnQ5EV7Sw9htTgdonJBMnzWe18t2F6ctWk794xzJVtCh	118	162	162	1548878886000
119	3NLd68mqxWmHVWyuso68Etm1Du3YxWz31ofzTrYCaMcuB9qtaHiY	118	2	2	6	1	120	jxyFAsnv1vmRNxJiyt8TQwxe4g2Dm4MFJ5XT31pUsJeoF6nf8dA	119	163	163	1548878889000
120	3NLYKHzRcPzhJP6p1i4pxY4eKaqw6QiBKLyQXQzvku3ZBA1A7vWv	119	2	2	6	1	121	jwfnB7urgFjtd4RJqW7A5JJBXaQca3c9FAJB1HPEvTWCSaCsmjD	120	164	164	1548878892000
121	3NKNxapmyjkXJKNjPkC7AuCiPZ2nzGbpSDGpnZ2Ki7D8ZtGjVgxW	120	2	2	6	1	122	jwN66XhDvBtZPv6GcP5Y2i2F3stTH8RV7pD6TQebAmUw7vmkjkZ	121	165	165	1548878895000
122	3NKr5saJxyoQpCD13PUsLmyL8L1kdcqYQH255u73vwZzUZPBHjpv	121	2	2	6	1	123	jwbT43GThP3EGrfEBjXjvqnJWfNzYnnpNAAvG8SYz8zQWaiDHCf	122	166	166	1548878898000
123	3NKRFKLVrXHCaFUDVo3LRg6zhyYnyjskPWAgWC3hUHQzrz5RMymn	122	2	2	7	1	124	jy31mqw6UUTY1MMqFM4VSroGhDMyncB8S41DQxDhA2XF36oLTgz	123	167	167	1548878901000
124	3NKpxNTfbWQ4Dajbww4ULBDnvX7qkc5mw3tsWc49rkPbqZJbLr7B	123	2	2	7	1	125	jwvEVqcaAEumhJMQ7eDLvqN2MhkscSwGk2e7xBT1rT5jnFJm1Cb	124	169	169	1548878907000
125	3NLWKnWqimovFwukWTwREhr7UXRgV5oXEcS7aDvoHCe42gSYm8up	124	2	2	7	1	126	jxSbzmWUv3JnwnCz47KHSKYsRMvpozAtgovxfs7HyMNHPUwWecw	125	170	170	1548878910000
126	3NKLozRg4eVVtKLDu1FNBZATdSx5hCU7ardeWMV5WF8yEoMtT6PY	125	2	2	7	1	127	jwyrpdHppNhXkvMb8SLFbmyawiqso6muPGQNPaxRpYj8WJun4PG	126	174	174	1548878922000
127	3NKgjSnNmcvNn455p9BMcWA2qigVNkHmqbjQJqFNpoxS2r8PsxB6	126	2	2	7	1	128	jxsNuJK6BpGNdD5rXBXsGRyg6HWzavNZRhJkTmLjKKrg7XXFzo5	127	175	175	1548878925000
128	3NKbykQBKe4xJKCP4SbJeeP8Grqc8oqKf3GhZfkA2JssPQaQ5wv5	127	2	2	7	1	129	jwyAXMTEX2RtEAUUVEjAsmC3HbxsYDA6Tx14CcxZANUdgUFh3wr	128	176	176	1548878928000
129	3NK7y2CPK8gZr4TqSCfUcofmqn3j8Kqig4LMaPLAV6YCcLcD56Sm	128	2	2	7	1	130	jwV6PQcc3xzSnQSiRX11YqGcHSsc6Q4eidqbzvQeFFxpKisuRNu	129	177	177	1548878931000
130	3NK69EahVkT56dVQJZq59eoh8sCjM61KZ9UraBDw2TVQeFDVYA2v	129	2	2	7	1	131	jxDaabKjq58yaw8EVs9WpgqukNW8YH4ABBxfnQSiNcxEyJpwYyy	130	178	178	1548878934000
131	3NKxTe2nvsuPVqrUZUfxXzFyFJAGEvjifRD7tDU4QnWXp7CpGNt5	130	2	2	8	1	132	jy2AAj3BBrBRDFsiWydgBfFCCN1PJNUdbfeizc4c92eaCPtvgp4	131	179	179	1548878937000
\.


--
-- Data for Name: blocks_internal_commands; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.blocks_internal_commands (block_id, internal_command_id, sequence_no, secondary_sequence_no) FROM stdin;
2	1	0	0
3	1	1	0
3	2	2	0
4	1	1	0
4	3	2	0
5	1	0	0
6	1	1	0
6	4	2	0
7	1	1	0
7	2	2	0
8	5	1	0
8	1	2	0
9	1	1	0
9	2	2	0
10	1	1	0
10	5	2	0
11	1	0	0
12	6	1	0
12	7	1	0
12	8	2	0
13	6	1	0
13	7	1	0
13	5	2	0
14	2	1	0
14	6	2	0
14	7	2	0
15	6	1	0
15	7	1	0
15	9	2	1
15	8	2	0
16	1	0	0
17	1	0	0
18	1	0	0
19	1	0	0
20	6	0	0
20	7	0	0
21	6	0	0
21	7	0	0
22	6	0	0
22	7	0	0
23	6	0	0
23	7	0	0
24	1	0	0
25	1	0	0
26	1	0	0
27	1	0	0
28	6	0	0
28	7	0	0
29	6	0	0
29	7	0	0
30	6	0	0
30	7	0	0
31	6	0	0
31	7	0	0
32	6	0	0
32	7	0	0
33	6	0	0
33	7	0	0
34	1	0	0
35	1	0	0
36	6	0	0
36	7	0	0
37	6	0	0
37	7	0	0
38	6	0	0
38	7	0	0
39	6	0	0
39	7	0	0
40	6	0	0
40	7	0	0
41	6	0	0
41	7	0	0
42	1	0	0
43	1	0	0
44	6	0	0
44	7	0	0
45	6	0	0
45	7	0	0
46	6	0	0
46	7	0	0
47	6	0	0
47	7	0	0
48	6	0	0
48	7	0	0
49	6	0	0
49	7	0	0
50	1	0	0
51	1	0	0
52	6	0	0
52	7	0	0
53	6	0	0
53	7	0	0
54	6	0	0
54	7	0	0
55	6	0	0
55	7	0	0
56	6	0	0
56	7	0	0
57	6	0	0
57	7	0	0
58	6	0	0
58	7	0	0
59	1	0	0
60	6	0	0
60	7	0	0
61	6	0	0
61	7	0	0
62	6	0	0
62	7	0	0
63	6	0	0
63	7	0	0
64	6	0	0
64	7	0	0
65	6	0	0
65	7	0	0
66	6	0	0
66	7	0	0
67	1	0	0
68	6	0	0
68	7	0	0
69	6	0	0
69	7	0	0
70	6	0	0
70	7	0	0
71	6	0	0
71	7	0	0
72	6	0	0
72	7	0	0
73	6	0	0
73	7	0	0
74	6	0	0
74	7	0	0
75	1	0	0
76	6	0	0
76	7	0	0
77	6	0	0
77	7	0	0
78	6	0	0
78	7	0	0
79	6	0	0
79	7	0	0
80	6	0	0
80	7	0	0
81	6	0	0
81	7	0	0
82	6	0	0
82	7	0	0
83	6	0	0
83	7	0	0
84	6	0	0
84	7	0	0
85	6	0	0
85	7	0	0
86	6	0	0
86	7	0	0
87	6	0	0
87	7	0	0
88	6	0	0
88	7	0	0
89	6	0	0
89	7	0	0
90	6	0	0
90	7	0	0
91	6	0	0
91	7	0	0
92	6	0	0
92	7	0	0
93	6	0	0
93	7	0	0
94	6	0	0
94	7	0	0
95	6	0	0
95	7	0	0
96	6	0	0
96	7	0	0
97	6	0	0
97	7	0	0
98	6	0	0
98	7	0	0
99	6	0	0
99	7	0	0
100	6	0	0
100	7	0	0
101	6	0	0
101	7	0	0
102	6	0	0
102	7	0	0
103	6	0	0
103	7	0	0
104	6	0	0
104	7	0	0
105	6	0	0
105	7	0	0
106	6	0	0
106	7	0	0
107	6	0	0
107	7	0	0
108	6	0	0
108	7	0	0
109	6	0	0
109	7	0	0
110	6	0	0
110	7	0	0
111	6	0	0
111	7	0	0
112	6	0	0
112	7	0	0
113	6	0	0
113	7	0	0
114	6	0	0
114	7	0	0
115	6	0	0
115	7	0	0
116	6	0	0
116	7	0	0
117	6	0	0
117	7	0	0
118	6	0	0
118	7	0	0
119	6	0	0
119	7	0	0
120	6	0	0
120	7	0	0
121	6	0	0
121	7	0	0
122	6	0	0
122	7	0	0
123	6	0	0
123	7	0	0
124	6	0	0
124	7	0	0
125	6	0	0
125	7	0	0
126	6	0	0
126	7	0	0
127	6	0	0
127	7	0	0
128	6	0	0
128	7	0	0
129	6	0	0
129	7	0	0
130	6	0	0
130	7	0	0
131	6	0	0
131	7	0	0
\.


--
-- Data for Name: blocks_user_commands; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.blocks_user_commands (block_id, user_command_id, sequence_no) FROM stdin;
3	1	0
4	2	0
6	3	0
7	4	0
8	5	0
9	6	0
10	7	0
12	8	0
13	9	0
14	10	0
15	11	0
\.


--
-- Data for Name: epoch_data; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.epoch_data (id, seed, ledger_hash_id) FROM stdin;
1	2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA	1
2	2vbayPfb4BSsovYuTvoJsQjHKYu2feRjGBwWeUUXjTfSKr7CK38R	1
3	2vaHfBaUHKS7GYG6VpEp4Kn6Xjhc35wrDExNiZkwVj5aC95jvyk8	1
4	2vbpqYTN6DXhV4yuwpz62Ri57nuHkQWPouedFjjEKv3bgWh7kd1M	1
5	2vbwmHNtW4c88M1tz2L3MCFmKzqZA5EHsUme48Zw5XcPD1Hdsaka	1
6	2vbX7R1nJgZiVHJiZDrsULZiagmjZjW2v51zrNTM2QgoaHhe39co	1
7	2vaRr3V9JwZWU1ZZcioj8m6PRtYvyrJFaLNuRG78YimxK8mjFa3T	1
8	2vaWAKMxYxezLvdiXAsYPe6np6B9ZRDUMSxi3C8YbFbPysWu5pEK	1
9	2vbDH3yQGSp3C1i5yB1VaV5g8qoJUUzJKa9p7UHCe12rDBXYoAme	1
10	2vaRLLWMcDv7ZnzoJTGpzAuoaDF77UPZh5JgWKUNws2P1sMgktxk	1
11	2vbN8nqJwxGK1T79dMKsWZGPt4Fs5Y7zTZ13CBnxXc2rMZXLdu4g	1
12	2vaA6rGCDeS3XA19eVahAwhStjaHQoKVffL8bBEZ8dpSaiCtjXra	1
13	2vc3XVX4f6TAWFTqZXozVqq3P3vgmq9aDavH5uwcUvXis88NybUj	1
14	2vbnFYyVWhE56PtxJbaJx2iz1yjGsdG2Ec94NYkkY6ghcsExRikR	1
15	2vb9gS5HCyZoBMqezX3TdZKn6dKFhP9QbgTH7ncCcCASSYTwzvF2	1
16	2vc3JTtEyewCvVwMCYRNDdeshYA5PJ5UPnEruYpkcKEKdKLAAK7o	1
17	2vaQw92Qg3tJL7XLAPTKeuVZPFiNyrP1YzovKiy84yyij4HK1QN9	1
18	2vbF9RMkkC7ET8XywowHaxbYFDNqQxWvuk5xbraw4PkfoFd5VVWa	1
19	2vaKdrCWMdbfvZ8wQQ7e8QdBMiwZo96UhTU9BViHP7y87VycmpDq	1
20	2vbiYRha66oP6q9kUD5CrPbwbgLh8R3EgkeXgBtjsHK9DP4SSHDs	1
21	2vbtxhUe8YEUAzzxp3585kZzdyd3aYfd9w1wF866VkkwGV4a1Nfh	1
22	2vaEmhXQubVULaPXtNj4HXfCtHtQumFpaD5mmhpoqstLLbG4heQk	1
23	2vbMW4byCZ4CF9b2P9P4j3FDs6MphPcWxUV3s8KVueF7k4wTF39G	1
24	2vb4YiNZjuueKRs7JaewcvzozghxotkczEvsVtVLiiuF2boo4LNe	1
25	2vbnfPh7xm7FXT12grLUKvyeg76PRnA1PaKVLPGpMgNqq5Ydut1i	1
26	2vaRGrnP39qfzXoRgwfn1yHVSfHfG4D2icxzhM8NpJMZvbfa15Ef	1
27	2vaDjnQvpi7DhJkwgUgDbFyuaGuQVV91PuVHa8bYmzc1jhMng9vN	1
28	2vaCQ6sUXhnq2pGAq8ejHLh9HiM8vpjqypm5eKd6UwnzJYxqAPYq	1
29	2vbr1yyg1pPToE4FjaQSNSsMZgrh61WMAMQRaqFnnogGsHdbPneN	1
30	2vbJP6kv1ZKzL36ER9inTvW8VXkPHE8brfkFt327XSUbVdcYLZTu	1
31	2vbfAvxMtVenbGRRJpM9au5Npwc24QqyqwCcBqAfRAcU1y5UEwR8	1
32	2vanA7FvUBLRHh9VbecdbFM5pxvhE3aovsYAdvNAiRqkPzivQDGU	1
33	2vbmHyKV9ewfSCLoxfhpf7nMUwHLzJ5dznyPdiAmuhgFhar4zWkC	1
34	2vatpkwJDNHWJVsakAdvq5L84gip88Va3yA8bgDKFnq9MqSi7FPG	1
35	2vaEnz63n32BdY31TTNsGgZgQvzJXhSiafFTj4LBU1U9MbJLJtXM	1
36	2vbZhgKQ36VCx7sUjDHVSGngQN8MhMnWiZx9Xqwoh6UW2ymmueLC	1
37	2vbzVLas2Mb1Wyg6PXMPAfSi8Go4tWULsacAEAcNYMg48QFhgCFp	1
38	2vab7C5PjqF5u4VDENj6a4Yne5aVZyUnxruZzokFySCVxELsajLS	1
39	2vahPh99LmgjC4pb74epteq7kTUAUKDWDvoVPkoEnzR2mDptQXDj	1
40	2vbScw7rKgLKiYYhg8SsGLcNnGvxqVvbUkrMp4oqyzfE6Gpn8ddS	1
41	2vamQwf3zsBCEZxALhyjoN6xQBPoqryUva1o6AoRy4UZBrCeiFGe	1
42	2vbzyrEsq1WbQR7hxAWQrwxkGSxsDv5kmZiXEhNWqnuCMLW9z3wD	1
43	2vbXvjEHiASJ6QYGVrMBWhsdGdCPnh9E2Qxe3iU3V2SGTHQN2gNJ	1
44	2vaxfZLkyMXZpmhm3aiy8Kdx7kuNvjveWKUPsM3BtxoZQ8c2ChBe	1
45	2vbrTDHmEbn7uP9Jkc2tqDDG3H2ZckQb2h1bVdg12hNi8nWg49xs	1
46	2vbXKYuzmvHSnzLWxj7GURFPrBKozKxWRbGK7fBs6jA5Gya6hz3r	1
47	2vbkf5BRShyH5Sw4ULbPsrPDgQxroGGuzNHQ8YBY6go7P1wBVETs	1
48	2vaMQn2Wvr3ZPkzv6SXLK8YDzXKavLpTWn8pB4mGbrAf4kvVBcoG	1
49	2vag8oPLEkXAyNLBDYjhadsaWRF8mxCva6N1YR9WsMCRYYeCsxmm	1
50	2vahKvxVihEd1kCEwaQ8bYW4dVtNqPw4VGXGWYnDsQoCxY8E75Fs	1
51	2vb57y6KUDgUwo2EvgETZrWbvxbPdCQEcBDfiD95A5cN1pECXFHU	1
52	2vbaXGAc8qfQfzchYFMkwtoiHcUNHKwsh8MEGXkJxiW6c6jrrWHR	1
53	2vbkwTouoRric2VPZDU3seoLAaX9NWLUGSYggTq7zZPk9xWNRY8e	1
54	2vbEr7gfityhXvTbYKALZDKJsdZvwUS36HZi75gDQ4UQxDYoL4fu	1
55	2vaY5yDNnnhUBKRqQTsiqqki7vUKYp6cY8nPV1Bjnj6B6VbkydaC	1
56	2vbTBh25uqj6JhrJVk8kZHE3H6DCoBa3FmcGkmYbbm31zxC1i1pw	1
57	2vaEh7REUpmyfSyPwauyLF2Yytzcp54xy6qtaxEh5wRwTUF5nAUY	1
58	2vbBAmbFfZthoPvjuj2bQ9hEG2qGCSorW1P9V8hc452XjvM12kmz	1
59	2vaXqqbMhXZKr1Af3LujkvUJZnTdZ6VdMWoLEDoUqGSeD5MPSXXG	1
60	2vaAbftsuX76azsBGzBmt9tZbt44RkKCban5mQa9gQehYW1VkvL8	1
61	2vbChtK9TAjQyoZyVKkWEQCkefWXdPwCu9fMTVSybBrbtT1dyq2h	1
62	2vb9f2fsouUNUkLnPPtbS8iCWZyRp1BGc45E52J741hCtA6JGiHh	1
63	2vbfWhEhb8yfQBJGnuGNRa96YZZNs542AWHBcC3HpUGK1A3cBpZi	1
64	2vaRFyGBCEoDSF8cNADVFmakq6s6EFFWg2TVnR8K3aze45QUshs7	1
65	2vaTXds7Eo6f9LjgngMb4gkxTRuMjJQEJxUfdCQrzRYBbjWCtcuw	1
66	2vbg6jeyMTCBzSKVsBhit6mMubp29qoyJ6pWfms3VbNJaebfwKuw	1
67	2vbQSjtJww4K4k4DvRwD9foKh7WaxCUxd6EmD2enURZjcXGCrWex	1
68	2vbUu74HxGXoTRAC9diuStgWbBufq3SBGbHAixukPJkZ25TjCLQ7	1
69	2vb6THchHLJgjWohkowXzLyPFdWkEXNaBsTUY4Ktk1pP9k6FB5y9	1
70	2vbJsYJ76cYK5KRCyi3HSUbYwetcFgGxMnSSycJw43rpmuJiJQnQ	1
71	2vc5LPnSzfaKh2RQUk1u61upBP5VbAs9nhZQzT3fwDL5FaidbrFs	1
72	2vbwwBwe3wuradGd5zZRXRiznZqovQdSMoqLig95jZ5BLdAvd8G5	1
73	2vaF8EXaHf1WvxEcxB7VakHA93peHUci7JMxfRFLEocFv1nWQuM7	1
74	2vaWzYgFNpwqsQ9KkDdMnavg9PEEjYr9Su8bJ51xtPzTo4SbaeHm	1
75	2vbp5QAUDeMSyw6UmpD457A6Psh1uTWCs55sUGurdHt31kmGVi78	1
76	2vakDVvUAUjCFV3tqFc2RkcUF2q3tdSuv9jWJJiKED5GyzebRVM3	1
77	2vbS1sUBpy87Xrme5ekwnTApRPBeP3MrZRg4dWpyVFLmhsoqNZKC	1
78	2vbNEqRyVVY4pxWpsMKJJy2fJzFX9KLV8fF3chfTWn9Pqo45u4aj	1
79	2vaPyUyzS1QpchAsedbcazas9dVoi9QUW4rh5fiLvNTh3cDYd4xH	1
80	2vb67ZTS6VASpXmnHmhZs5aezGcYgJ11VTwFh9K9xQm2FH8bXsv3	1
81	2vaVsAUxAdfLf3HcmiZzkRejvsTYZKa44tutssy4JC8VARAJNevH	1
82	2vbcKcWv8NWB83iUQWVBsUZDXtxZRy2ry3BbfHERztML8bsxPMvh	1
83	2vb8Kw9Yx7SUx8Cp8AktNvftJEZW8bth6pnpTrcWMxSnw9M16S3k	1
84	2vbuGqGWKbVp4EoPQYWM2rWUyTKJ75X7EQvtpnEEFJJP8XVRGfTe	1
85	2vbEacKqsvBanSgoeRzMnW3GXiab2VSnMMta34ioP1H9NfcijLxg	1
86	2vb4LP64nQKWVeMvzPKKdKthtHHcm6kkhE8nQWdzGBHSQ1JhYatm	1
87	2vb8DafiDH9wLxebpKjxTcnVMxNyEko3MYDSsz2ZLNg1tEc3RSHG	1
88	2vb5MdRAyHYA72dBZ6CLudmuq6MGwrUtYkq3JbEaKXN2C7SfCYdb	1
89	2vbVFYYgEVByNbNzeSnFfC89LGEaofFWJcGXadgQTQqbCxL7tqyr	1
90	2vbVWpor6Hf2zNeFRhhYypED1oEz2M7MqcwsxWD6Xmz3ifrwgXBx	1
91	2vbrzsEEhtfbasjiNDituuXXvncUTtam56PUEjFzF5TdFjzV1Dhg	1
92	2vb8m3H3Lz9jnXXvAecuYc94YEub7JcGFgouy78nsaSD4gZ2tPeP	1
93	2vb7tRuvCFnxWQhtmKuCjshQVDJvnR2Fqg1AZnYS1pAqbWymJNpC	1
94	2vaJsu3Bxmi1YxyiS4Dk7xdFJWVic6xSwKozh4hxqkoDZ9aMjnGV	1
95	2vboVsLtJQzCiLC1WVidQUjjdbJmBDvXXCq6cUKgXgZ78Umu6B3Z	1
96	2vboRdiMiehieaHyNmh4pUVt4TJPPgNJadAbq8B7ibzyFAJ4AyvC	1
97	2vbmEmUMvrifeNfvsH7QLhXFhXnEH3Vt9fkPoKs8sJKYMnPpZQ55	1
98	2vaUczd8sJ6geZryr2MpFVXtQnRQH43sSQ442kB4wPRQhqGfEewQ	1
99	2vb2Bsdgu4jbCJ1bhB4nuRjGwceS94BRPHSKruvt25GcfRC3wDp6	1
100	2vawENvRay557AnD2HFPTkAUiW6BbsoFPPHPmeV4JARnbXK8dVpA	1
101	2vbPUpQHDr3JGa2Xxcb86BSZYx3xTDNPJi53h3uJafNNKfbR2xKC	1
102	2vaTozKB24HJFTqu7kLwS7yueatrATwMbQDD15wE1yNGqCeQTxnk	1
103	2vaxGr5TnRaf5Khxb72bLJ3C5wzjmDK8qpwbKPxNCa6YaMNJUYQG	1
104	2vb5hC1TJMpeLaGvnQj1GAajqmUm3ZjaiJuCQ1Sg5E8p3mz5AreN	1
105	2vatJ8Z8LFyzSvLEBR9LM7ZvHhrGxinhvBUD1V83g9AVvsKYNfGd	1
106	2vbk8TuwAc1BHexApgrBN9RcyE2b6HRkhCA8KQb9fVEtJnC5DzNE	1
107	2vbH2eZv2kACpmEhYJHV1FzBYgnRoDUzX1pXqiNgNgpVfnJBnB4v	1
108	2vbKwDnro8AfNYA9h7h5pnsiekhZ91G1zT2GHkGSGYJMenj5Goiw	1
109	2vaCYc4Nk6SnuF1Tie79GRJdKhRMPRxvqHqBfjP6bs3bLJNAzeTn	1
110	2vbhmF13FE2aZr69S1K4exx5UWVVQjEguGRGe7jeT9VmttFTq7mY	1
111	2vbRZmmoERiMMbQdHxEQKA2fFHAbygFuWZwqhk5am4D81onBUqyw	1
112	2vbjo1J4k7SRoUtTED8L4we8cD1rqQTHvCEPAeYijpULy36ecEMF	1
113	2vbQW3ckCkmk4NHH7f3atp1khZufrGSjFeWAttC85Trqgjj1pbx1	1
114	2vaeyiZC77PWBAdcHtYi7AEouhHT5KzEMLYn7Ym6fZtjJD6MyA62	1
115	2vbacYYPpfmYezbjJedGRQwPoPcwqc4cvq5yaiYfGFxheUT4MgHo	1
116	2vc3RLccf9fgMciQUS738xJjjbAptwQsX6nff92GWVpzvKGNqDwX	1
117	2vbiUmnQhxgXSbEXjRF6dhAv8oAaAf3ZyimcrjiCx1w1e4Bt2Wrh	1
118	2vb7uRd88F7cpk5UyxgRX9A3BCzmNp54mSiJxiod8ZJcFKLjbDnv	1
119	2vaeLDhcQURgD1bv27SFKCN6QQRbuRJeNJPLGif2TvGQa6Y4Ukqd	1
120	2vbp9aciibyuz9Yx5HXDRKpvZS1kCYYinoPFwaxT6SQeXGpLgsnw	1
121	2vbn9JDVLdAERPr7jLpcXhutJpM6VDXUxQPZzESxQpfKMd1ZiS1z	1
122	2vbAY5h5tn7SyTapdr6xbreqF9SGyM8daVihwBnRNmC6NGjXui7r	1
123	2vbWUzCscSsv7dbSE3na3j1mm7V83Eq3J4ZvxpbBbLpj1cZQZaLA	1
124	2vavu4D99hA5C9h84m9tdexooSZKywD9HTnec6TgtvqzBsyj4noH	1
125	2vbV9gwm9ui9XkhS2TbEdifVoUVFVQAosTwdUZb86gtp3GNvNcfR	1
126	2vawz9UAsDxcgUUqhd8xx9H8BjYG4PwhQt2xpZiyn2frDWMDjtbF	1
127	2vbMyPw5AP75pGA5PvpQW3cdbvrsYcaemJLi7KLnmHoQPLvQCmhb	1
128	2vbAUipsiAKJNVAPX26Mm2NJAeovJrMq6eEFk9cKgb7uX4SVfCq4	1
129	2vaAESsLm75M7bCxAV9AJ8uVivq9YYGCPGN927gRrztjGh2UbSfh	1
130	2vbf8HrRq84SnYbwWTsvniS81u1iPCk7vrFmtKcggDjEebEwmen9	1
131	2vbmMS2WTU7EKJE95LhUP48MANTSSi8sQp6GHiR9zfH4h7x3EQKR	1
132	2vacxo5DLTJ1XrH3pSgHfLS3NbmTEHSYPqW5zAsWf412RSwjJ4AG	1
\.


--
-- Data for Name: internal_commands; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.internal_commands (id, type, receiver_id, fee, token, hash) FROM stdin;
1	coinbase	2	40000000000	1	Ckpa1Sx1jGfARVF1Tf2Jw3NyLzErn8BjHDjRY37NF7kH2xSjavB7K
2	fee_transfer	2	2000000000	1	CkpZDcCYoiiBbDEo7ZRbbAC2rYDVgfVGCpCZK7Nmo7L9iS5wmS7zn
3	fee_transfer	2	7000000000	1	CkpYzHRafcsexCiaHyfaUc5zu7iVTDhi6Mw1chZRSLuLs4EPqEfr3
4	fee_transfer	2	3000000000	1	CkpZQNB3LonSZeEfG1L4JU9Y4xrAFyorCGxxXe7FSqEDbidL8PBaR
5	fee_transfer	2	5000000000	1	CkpaLUyrUjGqQTJLuqcKtryMzvXEYyggYiYu3CUccaSLyj4VsYS1y
6	fee_transfer_via_coinbase	5	1000000000	1	CkpZkD324cgQfL5aD6sNEKAa1Z73oVgZyTzbDDzHcm3JDrtxK3EMq
7	coinbase	2	40000000000	1	Ckpa6YCks4GpQh1uTk3Z2rCawMQQSuZNiwTPCpz7hzz2EqeSFdoJs
8	fee_transfer	5	2000000000	1	CkpZNWbZ89DWJBEujLH6yH376bDvsNkGdQt7wcAPwb5jQxK56djDs
9	fee_transfer	2	1000000000	1	CkpZHwmGWn7VX6SfbP3khJHeDwPanP5qrfdKDJUTnkPQMXdB8eE8j
\.


--
-- Data for Name: public_keys; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.public_keys (id, value) FROM stdin;
1	B62qom56dHZvJvuZRZ2cCGRqB2UdCjoDRQjQRKfZyxX1SBTbF24L7Pt
2	B62qrPN5Y5yq8kGE3FbVKbGTdTAJNdtNtB5sNVpxyRwWGcDEhpMzc8g
3	B62qoDWfBZUxKpaoQCoFqr12wkaY84FrhxXNXzgBkMUi2Tz4K8kBDiv
4	B62qokqG3ueJmkj7zXaycV31tnG6Bbg3E8tDS5vkukiFic57rgstTbb
5	B62qiWSQiF5Q9CsAHgjMHoEEyR2kJnnCvN9fxRps2NXULU15EeXbzPf
\.


--
-- Data for Name: snarked_ledger_hashes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.snarked_ledger_hashes (id, value) FROM stdin;
1	jxg7fB9SZMZLcuhLfHMwGaPFUAn3Bg2MNadrFckhwHqT371AUvL
2	jwZG2JKgeNfxh67r9T9PtSJLFMterqqkvWEaKPY5duTiqNqZHvV
3	jwY8uV3WPYVGn8Bs7NcEtBaTAWbmtvqDV6YHdMmrguWb6QFBX8r
4	jx95ismayhhh8McwN2Vi7jP6cPQFbxNWg1XfdjcxWBBQceD9VvU
5	jxXmo8djUZ6mAbuzPc6m45xCJXRLAyncRTj3KiyCe3BQGxMhNje
6	jwPBtYVqpPi6RxYsj1T6KhGf8XScZC3EKDNkxQqyXwY2wm1oUeb
7	jxfDgQeyX2u9zohDMrTySqbuiMvP6uN2kijnTovegQ7hzLyB4ny
8	jxoQ1oAHdPukVaEGwdALAccKEe7W3NeJs44rZzz6FNiWvR7nd1s
\.


--
-- Data for Name: user_commands; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_commands (id, type, fee_payer_id, source_id, receiver_id, fee_token, token, nonce, amount, fee, valid_until, memo, hash, status, failure_reason, fee_payer_account_creation_fee_paid, receiver_account_creation_fee_paid, created_token) FROM stdin;
1	payment	2	2	3	1	1	0	5000000000	2000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZw188az3F6TZwfohZHqHxBaCkpk62XP116Ti9rhhmM4iWm5ftC	applied	\N	\N	2000000000	\N
2	payment	2	2	4	1	1	1	1000	7000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYqvnEagi7yMkRRhHS2SFmqdwuSxK9zYAm9mMpbB8CKcPMW4D5F	failed	Amount_insufficient_to_create_account	\N	\N	\N
3	payment	2	2	3	1	1	2	10000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYrSALDNkHgpU8DrhSDBbiN5NtmBUy7CF7ofEkq6NrWHmUuKagJ	applied	\N	\N	\N	\N
4	delegation	2	2	3	1	1	3	\N	2000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaJhZQtVqHz1cPemeP6ydTeYaY6ohGwwTqdoWBNbSeo6Hk4qCzk	applied	\N	\N	\N	\N
5	delegation	2	2	3	1	1	4	\N	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZsSaKjuztYL9gBtoZaLWgVf9JxY31MYVBbm5GzY8hKxxwKvobB	applied	\N	\N	\N	\N
6	create_token	2	2	2	1	0	5	\N	2000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZWUhyi5zAZAvVhxbRyQq8RZbwkWH3HcvjADtXLGPikCaUiCHEE	applied	\N	2000000000	\N	2
7	create_token	2	2	2	1	0	6	\N	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZEDtnRVuha8s2qc7tYW8ZGEpyhP4cEk4zzV2npG7icWmHUeGLz	applied	\N	2000000000	\N	3
8	create_account	2	2	3	1	2	7	\N	2000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYqHkJTZV5Z4m2jsBv4Yij5cYmDi2PNaKx8DUAv1QLpzK92WTje	applied	\N	2000000000	\N	\N
9	create_token	2	2	2	1	0	8	\N	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa6zJzMCypmTbAw1nm6UQ1zNVPK1Yx9WR4fCU7rqw5666AuGRZk	applied	\N	2000000000	\N	4
10	mint_tokens	2	2	2	1	2	9	1000000000	2000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaFGaUchQjSqY7kJqdk1X3oaWpZoAufHyrSaKEBgakYdi2sfbx2	applied	\N	\N	\N	\N
11	mint_tokens	2	2	2	1	2	10	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ5SqHh8kLf1AnjWDv3sdSvXVSsaqmZ3ipoyYYZBwbruhFHm5NP	applied	\N	\N	\N	\N
\.


--
-- Name: blocks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.blocks_id_seq', 131, true);


--
-- Name: epoch_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.epoch_data_id_seq', 132, true);


--
-- Name: internal_commands_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.internal_commands_id_seq', 9, true);


--
-- Name: public_keys_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.public_keys_id_seq', 5, true);


--
-- Name: snarked_ledger_hashes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.snarked_ledger_hashes_id_seq', 8, true);


--
-- Name: user_commands_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.user_commands_id_seq', 11, true);


--
-- Name: blocks_internal_commands blocks_internal_commands_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks_internal_commands
    ADD CONSTRAINT blocks_internal_commands_pkey PRIMARY KEY (block_id, internal_command_id, sequence_no, secondary_sequence_no);


--
-- Name: blocks blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_pkey PRIMARY KEY (id);


--
-- Name: blocks blocks_state_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_state_hash_key UNIQUE (state_hash);


--
-- Name: blocks_user_commands blocks_user_commands_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks_user_commands
    ADD CONSTRAINT blocks_user_commands_pkey PRIMARY KEY (block_id, user_command_id);


--
-- Name: epoch_data epoch_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.epoch_data
    ADD CONSTRAINT epoch_data_pkey PRIMARY KEY (id);


--
-- Name: internal_commands internal_commands_hash_type_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.internal_commands
    ADD CONSTRAINT internal_commands_hash_type_key UNIQUE (hash, type);


--
-- Name: internal_commands internal_commands_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.internal_commands
    ADD CONSTRAINT internal_commands_pkey PRIMARY KEY (id);


--
-- Name: public_keys public_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_keys
    ADD CONSTRAINT public_keys_pkey PRIMARY KEY (id);


--
-- Name: public_keys public_keys_value_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_keys
    ADD CONSTRAINT public_keys_value_key UNIQUE (value);


--
-- Name: snarked_ledger_hashes snarked_ledger_hashes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snarked_ledger_hashes
    ADD CONSTRAINT snarked_ledger_hashes_pkey PRIMARY KEY (id);


--
-- Name: snarked_ledger_hashes snarked_ledger_hashes_value_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snarked_ledger_hashes
    ADD CONSTRAINT snarked_ledger_hashes_value_key UNIQUE (value);


--
-- Name: user_commands user_commands_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_commands
    ADD CONSTRAINT user_commands_hash_key UNIQUE (hash);


--
-- Name: user_commands user_commands_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_commands
    ADD CONSTRAINT user_commands_pkey PRIMARY KEY (id);


--
-- Name: idx_blocks_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_blocks_creator_id ON public.blocks USING btree (creator_id);


--
-- Name: idx_blocks_height; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_blocks_height ON public.blocks USING btree (height);


--
-- Name: idx_blocks_state_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_blocks_state_hash ON public.blocks USING btree (state_hash);


--
-- Name: idx_public_keys_value; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_public_keys_value ON public.public_keys USING btree (value);


--
-- Name: idx_snarked_ledger_hashes_value; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_snarked_ledger_hashes_value ON public.snarked_ledger_hashes USING btree (value);


--
-- Name: blocks blocks_block_winner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_block_winner_id_fkey FOREIGN KEY (block_winner_id) REFERENCES public.public_keys(id);


--
-- Name: blocks blocks_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.public_keys(id);


--
-- Name: blocks_internal_commands blocks_internal_commands_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks_internal_commands
    ADD CONSTRAINT blocks_internal_commands_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.blocks(id) ON DELETE CASCADE;


--
-- Name: blocks_internal_commands blocks_internal_commands_internal_command_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks_internal_commands
    ADD CONSTRAINT blocks_internal_commands_internal_command_id_fkey FOREIGN KEY (internal_command_id) REFERENCES public.internal_commands(id) ON DELETE CASCADE;


--
-- Name: blocks blocks_next_epoch_data_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_next_epoch_data_id_fkey FOREIGN KEY (next_epoch_data_id) REFERENCES public.epoch_data(id);


--
-- Name: blocks blocks_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.blocks(id);


--
-- Name: blocks blocks_snarked_ledger_hash_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_snarked_ledger_hash_id_fkey FOREIGN KEY (snarked_ledger_hash_id) REFERENCES public.snarked_ledger_hashes(id);


--
-- Name: blocks blocks_staking_epoch_data_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_staking_epoch_data_id_fkey FOREIGN KEY (staking_epoch_data_id) REFERENCES public.epoch_data(id);


--
-- Name: blocks_user_commands blocks_user_commands_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks_user_commands
    ADD CONSTRAINT blocks_user_commands_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.blocks(id) ON DELETE CASCADE;


--
-- Name: blocks_user_commands blocks_user_commands_user_command_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks_user_commands
    ADD CONSTRAINT blocks_user_commands_user_command_id_fkey FOREIGN KEY (user_command_id) REFERENCES public.user_commands(id) ON DELETE CASCADE;


--
-- Name: epoch_data epoch_data_ledger_hash_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.epoch_data
    ADD CONSTRAINT epoch_data_ledger_hash_id_fkey FOREIGN KEY (ledger_hash_id) REFERENCES public.snarked_ledger_hashes(id);


--
-- Name: internal_commands internal_commands_receiver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.internal_commands
    ADD CONSTRAINT internal_commands_receiver_id_fkey FOREIGN KEY (receiver_id) REFERENCES public.public_keys(id);


--
-- Name: user_commands user_commands_fee_payer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_commands
    ADD CONSTRAINT user_commands_fee_payer_id_fkey FOREIGN KEY (fee_payer_id) REFERENCES public.public_keys(id);


--
-- Name: user_commands user_commands_receiver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_commands
    ADD CONSTRAINT user_commands_receiver_id_fkey FOREIGN KEY (receiver_id) REFERENCES public.public_keys(id);


--
-- Name: user_commands user_commands_source_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_commands
    ADD CONSTRAINT user_commands_source_id_fkey FOREIGN KEY (source_id) REFERENCES public.public_keys(id);


--
-- PostgreSQL database dump complete
--

