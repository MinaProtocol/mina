--
-- PostgreSQL database dump
--

-- Dumped from database version 12.4 (Ubuntu 12.4-0ubuntu0.20.04.1)
-- Dumped by pg_dump version 12.4 (Ubuntu 12.4-0ubuntu0.20.04.1)

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
    snarked_ledger_hash_id integer NOT NULL,
    staking_epoch_data_id integer NOT NULL,
    next_epoch_data_id integer NOT NULL,
    ledger_hash text NOT NULL,
    height bigint NOT NULL,
    global_slot bigint NOT NULL,
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

COPY public.blocks (id, state_hash, parent_id, creator_id, snarked_ledger_hash_id, staking_epoch_data_id, next_epoch_data_id, ledger_hash, height, global_slot, "timestamp") FROM stdin;
1	3NLuch1cu21qEB3QiMyY9akLQSYgBKmYcDhX865sypZS9M7xzFjo	1	1	1	1	2	jwcYgfQcGNGigQqUmfSt5XfaHiH4XtoRQKpbkCQG9szbmDcwgAx	1	0	0
2	3NKcGRKBaVGfwyuTQuzR3wDyMwdooT3PsgB9SBmFkgN3wYdAWGgQ	1	2	1	1	3	jx6GXW9BeQfA96xgu1nzpu9PmpWpTyeY75yRLDivaHSuXoQCJCR	2	2	1548878404534
3	3NLXhg26Hf6cDvU9DDPs4bTpdYk39o7mwpcs2vyqPqULE1ATcSgP	2	2	1	1	4	jwgom9umDmrSDqYtWFTtVdeJVo7Cju4TXDbXfBCqXDFfHqVMvJj	3	4	1548878408648
4	3NLJLT5yEMzq8jGMAfGtJjKF1uTiVz7mA5MabDUSRaxLhhQNfUFQ	3	2	1	1	5	jxLjfwWh7dmXAnwTwcPZr9LoE9BC2nBkAQETD9Epq9yiX6hVrZ9	4	5	1548878410067
5	3NLcRKDuhpqTwpf4ouFKxve7aPrWnqD4nubxQd8EXZgpaocPLYU1	4	2	1	1	6	jwaSZdCZpR52KfTLktpYDk68CQ35FLH2tnuBTMYtZAX7GHVkSd2	5	6	1548878412000
6	3NLPgcz92dchGzX1GW5Zhcxq9xVrobk6WC8ZHUMu9zkLMB6TZdpa	5	2	1	1	7	jwzMT1jZ88ZZuaGguf41avKCecuJ9Gr1o8NtHX26MBUeMuHzvV9	6	7	1548878414000
7	3NKiCx2FMwVxkAPQA9KmVpRQdeUC2g5smAE1jouXUE42h4spmedT	6	2	1	1	8	jxWxJa9DzqCRKtvrvr5Lc4gpAkDAfNoXZTeXHQcEh1EVf7t7dfC	7	8	1548878416000
8	3NKzCszmVDKRmVujYtumLAyGYYYzUtnx9HhhZuS153xWHN2GnJiP	7	2	1	1	9	jxqiERhK1XWkrLrs7dVB3hqKt1YsPdzU3D7QbjMoyGw32p5Tn2t	8	10	1548878420000
9	3NKzHQD134DHYtBE62Aj1PxETgpBNCtihWzQJys51nmsibkpPfMb	8	2	1	1	10	jx4Tj6TKacRuZr9TfgpC6mtpFbuQMtAJLFHsFdEadYnYr7ZpBin	9	11	1548878422000
10	3NLGqt1vsoJXd5yWwW9dh2T1akcoVXmf1pUnZQpCsvz4wBbJypYq	9	2	1	1	11	jxGj9SUjfNtv9NUmq4VwMghWmdrBdbj7uSgoCUQtYysASbaPmM4	10	13	1548878426000
11	3NLLLFE5T3nqBTBxC74xBcaH1qtPKSaZ4sFVS5c9NuiesMuguQAd	10	2	1	1	12	jxQNEe4Saxxe6cbH18XkST9jLqpdxoptZkJPeSn6jAgz5yG7Hie	11	15	1548878430000
12	3NKHEiMAD8bCtwjhEE14vnGNmuczQe8WUD4FcisNXWxmUmyjz6ah	11	2	1	1	13	jwB3WkGsSFBZ4srzJaDjDsSypfYUHe9MUC5yYKkE16x1ewxu4hM	12	17	1548878434000
13	3NLriGJ3MV2oaU5goYprQ7tpcjs9FEFM6jbVpKJcihP9x5ztJe22	12	2	1	1	14	jwAffXfTcjUxVqqL5youbyerBYqoVdSaxdmLShw8Nq3qu9Pj7iA	13	18	1548878436000
14	3NLFJviHswLbjKQ1CL9a3xzYLN1bLpiAefNiQ6DDioho9wP621Df	13	2	1	1	15	jwnaxuamuEdiS2YxKumdMWGeTsDSzyqhniqRmHWq3pbEBSXCX54	14	20	1548878440000
15	3NKT3vYDPz39Dv7Gh9iMG2vuPPGpNJXNKHbGgHh5aTFVPc9vPZnp	14	2	1	1	16	jwmh8ApSJsEPBcjWNGy1zxm2QnNwrxcgvpayBR4ULxwjp3RUB5d	15	22	1548878444000
16	3NLUCccRdqwh9MgzJRrGx1N4VyY1jZnahe2GJVoEZ6tubCa295Tz	15	2	1	1	17	jwAHPEHwmTgf4QBqFB488zWU6LvbXKggmBgpSUMLszsXD6AYPm8	16	24	1548878448000
17	3NLS2dzyrA6WywZXSvxkVmcW1jKVwtM39chUmo9syjsVR8b7m77P	16	2	1	1	18	jxdaifb4vdvu2tgHbjq4uXLA4ZNKxHL3TcptszyDj9M5YdEYkyw	17	25	1548878450000
18	3NLWG7yRLwmcdYP6oQbFB3uvgJ4MkESbtfpe33QzedmD9JEMLiAs	17	2	1	1	19	jwmUqBV8V4a2n9EMnLzveYZTEhCmbTsLAzgz8WorSq9uwXaYD4Z	18	27	1548878454000
19	3NKK6mn5gYKe3zyrLXbNvy2GWM36KPbKDEA2cnaZrTE7YvU9gnQw	18	2	1	1	20	jwVedqTiu74jJ4RN7LiPwqefJ3rLWw9NTQPivP1REUgQAL2R79E	19	28	1548878456000
20	3NLDng6Eu31bQNSHQVXd3fAmCLrTm8DVAoPhVeaXMrM6GHqFy9MD	19	2	1	1	21	jxJPjC3fPSX42z1abYmM31reScnQLy3ec1Zf5U62aWAYHcfeQsq	20	30	1548878460000
21	3NK4tAg8mF1WKXAfiGzrmbowKbKRSXiT15V6xhiuNwhx2DWyQwwX	20	2	1	1	22	jwayGJncpZ4jQ9SyztfZsQi71Sn4RYLDuzWbuABagTQ1YGBMzNV	21	31	1548878462000
22	3NKdj3nsQG8KBvJSzUMPV6bvLrUANsWjE8E5Nei1aXtPctQ714sf	21	2	1	1	23	jxcGmfoHXyT4Zkyzwk32azdXpw5hWcHVuWi6ukvnnVbgtrz5dWt	22	32	1548878464000
23	3NKQyfZh2Gi18oSWpjhBTAYxxoUB5kfJrAAzWuzKvLCKxjxpyTbb	22	2	1	1	24	jwXJ2hgfWQVGkGqGg7Ci6BCeu9U1oBsrVAtfsfBFhbQgndipi8u	23	34	1548878468000
24	3NKTr2yxXpTj4rKmRUNfgpwTJtdR8wv9tkajffFjKt8PR2MryWbS	23	2	1	1	25	jwQHeeFbAgx7mFwfSJ2YQF653ES6k7BmbkFRizcqNXm36bmaQVs	24	35	1548878470000
25	3NK5UkropvwZZ6JxZ7TMuSgXYYeUp7hLWVX7rkqSa5oMeAt7RRLx	24	2	1	1	26	jx6DrasMUPXcn1EiRQcsYN6g1RU5h8a8h63YxwT6chg2rXwER6E	25	36	1548878472000
26	3NLgX8tXozmWm8qhjUkFncxVPHrcW8Q7rekxPxtf4pjCJSkZrLmX	25	2	1	1	27	jxaMEdTQumqsBEWgtJfAjgxCEPnhZcCeMM2fQyu14HmwknYKPUM	26	37	1548878474000
27	3NKcnWFvqDroQwnLn7ZuQQaD2dYaCWG5nMtW4AC6ZngLWm69x7P5	26	2	1	1	28	jwVKKNjKv2XBnUUjEPMuGwaQ1mLbC7hyj8bGYMLWb3joHYJ9EPX	27	39	1548878478000
28	3NLPCsFbjgHCxW3a8ommFARrpxxGgf23Mr4wZDMJe5TZN81HBjFr	27	2	1	1	29	jwjarc214PcDvBTtZTw5WKkAtZXuY1PH1D1STTV4vmmgLB3kdpH	28	40	1548878480000
29	3NKAxVj1pi1qmJt3kpoB6TLsr5RKiN3RYpcWvuF9KA4RQYsALc8s	28	2	1	1	30	jwAfixGx3d4Z4dExbsNRiNA1Ti2MAh3X6V4rjzfjUKWxK4UsDwu	29	41	1548878482000
30	3NLhRZiC4Z7ezKowHzcSpDYKAMPm9bAqPnRyRDWRD3dZaoyku6tt	29	2	1	1	31	jxf3iAaQaM82KdSfN9q1vaQZH3eGBy2SBdYGy9zsWbTuHcPAQGr	30	42	1548878484000
31	3NKWDaCiNsVoFc5oDfAyyyEFfj8Zo3ZsaP99zu123hytUxN6Ak7S	30	2	1	1	32	jxVWXwvKvHAM4kMeojndKiVwMyD3AJ1Du6G1jWgcYChVYXZz8RL	31	43	1548878486000
32	3NLornWQpvDh1j6NcGHRnwu7Pk1ARKfkmFHwDiEtnopCMDAYrCyQ	31	2	1	1	33	jwkKxtTPjDGj8zpcPn7XgnDe6Ls4FTE5JGAH51WmdWLbpCLg7yL	32	44	1548878488000
33	3NKVKEeeas9qKTLoYZBnirz8NYyAWyuHS2iwy63shfNVc55mvRVM	32	2	1	1	34	jxNJADyMwHBVWJy7QrtaspxuvSQ97H62PWyRDWq3DrmgpqdrWuC	33	47	1548878494000
34	3NKCpguGrH1Qv3FcAgWjuvmFGgSuYpw2pCxYtQ4xpzEsUBWpRSAR	33	2	1	1	35	jx8ahDts7YPDJyt6rAPDi67XvApnbkmMCqyWJDbDotKxMWxCwH2	34	48	1548878496000
35	3NKoyAxPYCkxajNo6LfrTwegnSjt2VUtYBrCMcR1eVbjfcWH24PM	34	2	1	1	36	jwsk7DnMSpofJ7YGKw1HdwvqXFAfYJxU3XoLp1J3GArgkKoQLiu	35	49	1548878498000
36	3NLkrsof7YRDgemPhUsztgtZzkDqghEh7Cbn1eTGhKiFWnenEUFo	35	2	1	1	37	jxUfMKx1bW3qLvs5NSifJHuyStdhM3f1CV27xnTeWmGZC4fXQT1	36	51	1548878502000
37	3NLmZu61oGp63WpxSdmxBDq4AQRW78uEyJN1fBo8kTFENEzxqG1r	36	2	1	1	38	jxT8S6wGx8znJ5Dxug3YHVSHRE2UtTZ2wDgHcoC37wZ7uDS2CzY	37	53	1548878506000
38	3NK8V6znTjzrgwZZPM2k2JZGDUWRhc7kwKv91Nm9eMjAZvMQNAuj	37	2	1	1	39	jwpmLkKssXvL3i1b1gDHhqY49RF6TZTa3oW6HYJByM113KA7KAY	38	55	1548878510000
39	3NKpD7WaRfSreB14YfDC94zu3emh7dYib7avCHbQKMaeXmtSt3Vm	38	2	1	1	40	jwyBDG3BC9xJarWje1QGF3wgdVGmgb3UzXZBDiX3uxjEpuoRsAf	39	56	1548878512000
40	3NLZVDw4T5n6WrxnXXm7PARKSun4xNuuj9GbTNJtT8N7rHibbgAQ	39	2	1	1	41	jwiFT24drN34W85GKJpkaGGTuuKVuxL1kQK9HspnzcnrjdbqHhq	40	57	1548878514000
41	3NKZh1EgBDV5mk9U8B9ZDu9PMBfCx6XNyNr9BbdAVfs3ZQH7oHs6	40	2	1	1	42	jwTePcxmiydGpLQpY8pqkLPjWP5D5tWcf4rZEq4i4xMF2KSJ1aT	41	59	1548878518000
42	3NKeCtg7gosLsLXDqd4z55eeLEjeoNZuBTaLb1AiwHjtYPTJzxDj	41	2	1	1	43	jwNLPFH17Sge9Z1YFUW7uTJQQXW8YC1oxeoYXX9rvZjwqTETQxu	42	60	1548878520000
43	3NL53Eo8Nk1CyKDmA4XbQACvUL3wQS9aSMggBpgPL3WavaHHzfxr	42	2	1	1	44	jwK3PpEBUVZyxLPFvwQrBpjW4u7CLFwf7Wug1NrLSBPqcVkrFZa	43	61	1548878522000
44	3NL5arJVFotATb5jAVJgPXZCFRXnX5w4kb9c1FhvaaeJ1xjQCU5a	43	2	1	1	45	jwA8mePeosmMLBEs6KRZRWVWpZkCxFHjLeVdwi4mN7vez7mArsr	44	62	1548878524000
45	3NKAff83fxeZEakUwPBZdrLmiQeZMnEFmUKzRmCz5qko3bDPXsYZ	44	2	1	1	46	jwdcgADg8qQYbLAmnv82ZWY2v11SREhZudN6yigaUNyvEqmwWPH	45	64	1548878528000
46	3NKdbAfY7ec52TKCFeGXVRnbyM4462uqZygrHwk3GhuvSG3UJjbY	45	2	1	1	47	jxNaX3JWxvLY17BC14uQUs5JCGK6hzyxF7hhqufvLppm4PW3YxD	46	65	1548878530000
47	3NKjekFsv5penx76XZgqUQNpfYpuBsQA1LZxdQQW2d3KGHUPk7ut	46	2	1	1	48	jxvMob2LqvHBBawf5dtxNiAHDJ4GM1reZ5tbXeCEbqdfCbKifjp	47	68	1548878536000
48	3NKJjZYH11tMozNrNyTs2DmaCtdiVYAejMjjumePxAGpN64kjMNK	47	2	1	1	49	jwubgkcLEMP7rpvQMK9LHyGcWBixNUCaP2UmLiFLH5Qg9DKcpGx	48	70	1548878540000
49	3NLG3KZ9xZZrBtXwFdM9E9xkg9NEaczWx1tG4KVLmyryMGGwjkQX	48	2	1	1	50	jwJ5o9HZNA8ohUQagtCJqmQ3wRMNyrBgkJLmDHV3V6yH7TrxfYP	49	73	1548878546000
50	3NKQBqPK9PjMDHe1zwSx237mKry7vSb9UYwj6LbRdgNSCH2fn7uN	49	2	1	1	51	jwTHLCgKZ6QzwdajkUirJwhwoT4iwfd6de5XBmopZ7dy9s5EBVA	50	74	1548878548000
51	3NKPWFcThBuXqmwTEKq6fhXvYv6ZBSMWHzDhCzctDXQDL6T5kZKN	50	2	1	1	52	jwQRWVcJBR6dZvyr2sa7d9jvbi6VEwzi3j3aP4CfQUizNSu5SFf	51	75	1548878550000
52	3NLgf47fG2QErKY39aBWk2qGs8FwGdBa1yhdggM4RMwofo1QLtq5	51	2	1	1	53	jwUBLFBbqGDCq68hYWQxLHLzTxfvGdD6vRJcTnqv2LomE2Cg31F	52	76	1548878552000
53	3NLNYfodtn82R33FSjRvQTxhy8GoAroLfHu2mHQHmZR4LTAtRUKL	52	2	1	1	54	jxdbmhvqE4VwovSJWg4BfazGjRbrEy8ejawjZpinjL8sbnxxLbZ	53	78	1548878556000
54	3NLRns6djmim5aZttKHhbP4DfKARRzVa7EBwy2bhaphhJczhSydy	53	2	1	1	55	jxu5fbEhQZ28RXoz1iAx1bEf2S7HKG3BCEhDDMBZVPyWwWyoYFW	54	79	1548878558000
55	3NLsthYscyX6PpnLdRzjaxnTgjHLknCsZHQHxrnBHC5A3YwHqpVR	54	2	1	1	56	jwc1xvei9NoByP9aT7nEueeuRUFTuHtuxR2jxvpJE5U2vTXEChE	55	80	1548878560000
56	3NLUzfgaFGd31c21JtMpSjeBArRdA5FWc6qHdNdHQwzaNNDfyrJo	55	2	1	1	57	jxq8uq4K2hjz3BKEe5VBBgMWJKcAvBTtbbvQ6GHCxRpHH6Xb8Vi	56	81	1548878562000
57	3NLLA99wfHt2TLzk6UQshDizB6d5Sry44C2UwvTW2vTzcTNeyzU1	56	2	1	1	58	jwUSfyyieVg3vL3NyieZ3NbZgwU8f98y9c2mEdwHmmvBucVJKqq	57	82	1548878564000
58	3NKvnXk2v7bco5xbjiw9XCXb6cD9SRt1sU5HeRfeLx6rrfNpqhPZ	57	2	1	1	59	jwNzE1iNLLz2nzWezGVedGrjD4dL9gxAhfMgWd8zu6ovxCf5uZZ	58	84	1548878568000
59	3NKz8e5DCn8oWm5otA2662ByDsjTLPiw7JLyKtv3b7aECG3Haafz	58	2	1	1	60	jxSzqaK1Aj4YgGEYhJa6cyoQSKHHvw9nTPWuVLmehqTrhxxo5p8	59	86	1548878572000
60	3NK6NfWL9ExKy48ojVBhbHvfZLB8JUAuk2jEnQy3RhL2LhStReiL	59	2	1	1	61	jx8YQrBppf4BWUjiCK2fVTKAiPWVzDMzdb4VC7gGtiERQx9oD3p	60	89	1548878578000
61	3NKto16UZy7ph5vuHp15AmPqTuDuJktgyM6za9dv6aBtpPd1Z6Xo	60	2	1	1	62	jxtVTe1mwG4D7vUwSPN3HCXHup7ZQBXF6Nzo1N3fAnBkT9gXk13	61	90	1548878580000
62	3NLc5QGycHKx41uh6cHffP45qG9V6RJzFpsDTeMBpnXyVZvMRQBA	61	2	1	1	63	jwBFp22dtesijvxJK2JDy4pRiM7HRsRFbHVHA3FEEz4puzN2SHs	62	91	1548878582000
63	3NKdtpbUEu5H8sdTsR4cuxL8c2D4u4TxAY6najRgD3g2fSoLGgSm	62	2	1	1	64	jxYsMBP1LBQJ6yCav1qV2rnVnnvziJYRmrRmF7LRbAfnA7FyQ14	63	92	1548878584000
64	3NKZmpzPNhjG5kZGpdgDS4MxwXkJ6dZvWtRea4pxU4ZKSbsuJupb	63	2	1	1	65	jwBLDgUE7291VKxZhSoMEc5woYV782dUwpDC6YpxrN8X1YFFAiF	64	93	1548878586000
65	3NKHzNyDXVLWmJdo7th2AFkRLECfETWbtcNjZqhnfWWdc2UtZj5C	64	2	1	1	66	jweRFoP2KzyxgBxJLRzdZPH1NaTQ4QsYDYVCYL6irKUnHc9xUYu	65	94	1548878588000
66	3NK3pG3YYYsGVdXGcju7z6iPphM5BdAXod56LWF3RLiCtvdKt8dC	65	2	1	1	67	jxHH4pVGC8pPjLfGioZzT6xgxbWbDogK5UnvKWqsVi9xuWoGUsS	66	96	1548878592000
67	3NLHuA67ndnUfgGoBNdxGqjZXc7oJCNdQisie1MzNKeQaUkXomXy	66	2	1	1	68	jxLC2uZBq7bny3DCyu49FvyfEyoMYxyJDYB3as8E8mXkhVMhH4B	67	97	1548878594000
68	3NKL8uV7P175MfQoz8MRVToGvPBUkdnc4WLSRdQg59E7E4w32Kkr	67	2	1	1	69	jxppUvbYCVFYeHx2deSpuqUjR9HjoEt4aDmq58G9PE2wiTX7NDi	68	98	1548878596000
69	3NLyDnpnZwuty2sUvZqAt7niDTB1g7nL12k5DhMWKDjXBNGkJjfR	68	2	1	1	70	jxfdGQivBSq42NXtf3CoRtMdso9vM85eSKXfdzJU8tqy7G3HJET	69	99	1548878598000
70	3NK5qTDnGuf4E2LPxjC1gPP9mywG18m4ycYDABnvh7nnTMnhFpt8	69	2	1	1	71	jy3LTHYmToLHNnNaQRP3uw9ukgqSbEPVs7FndDHhKc4YcQbycoT	70	100	1548878600000
71	3NLZFcgR7y3svjShGRSZwpQAZyt58HMfNPBVymxm1L4BonSvpKMi	70	2	1	1	72	jwxqWNbNfuuCd9oBvXZPYqHJ55R8ofW7Zav1RLYsnVgUwuLjtcD	71	101	1548878602000
72	3NLUW6FGp22btYFsqNrYcPD3e4onXm3XnGYJomZPzvniZU9MZU9V	71	2	1	1	73	jwUDseY6dgyPY9s3qWyQUmoLrAuLcDwsdn9FqF5FGxv5RJanv6P	72	102	1548878604000
73	3NKZQPTHdz1hqvYxypjkGiM3VRbtMd4ZvVpzsqK1rnpEbkYMXg93	72	2	1	1	74	jwgACJvp5uF9oqAaRA28xEESe1Q4grrfBSgq4NvAYU7GDTYgVW2	73	103	1548878606000
74	3NKgsixsTzWwsEmUuB8WXkcFbB34Gv4kd6YjqLbuLu19tGxZUgQD	73	2	1	1	75	jwQ3VZ9a4gZTuW63iy9WZUgpvvWuHN5aozuRvQLoK6kvsTaGDto	74	104	1548878608000
75	3NKcS8FQVTBVtfRNyTB5mLU8hzPya2Aau3YF2L5jBLSvd17oSgWA	74	2	1	1	76	jxdFPjqfFaVrJ6yktxHVkWWk7JpUNKx7cmtrhvvGFMTG7bYgGkA	75	105	1548878610000
76	3NLA4QQMurcZ35Epp4y5JWnEFriq5dQUsmDDTExcvB5vR4fetRu3	75	2	1	1	77	jxa5hjnJwvwcdf5VsbdQ7g4NXu8fMVuVryqV3z4Xc3bxSSYkdNw	76	106	1548878612000
77	3NKe1SvorNmX5ZAEXWUxxgUAGTSVeEXiE7oGGBSZRCTEqsfW3GHP	76	2	1	1	78	jwBbrDjdodE2KFNC2k91nuDTVVPbsA8JFZd6zGFBbYcdM4oD7qU	77	109	1548878618000
78	3NK8H6q1WEhSVQiQqQfJyYwnjEzHHmfjBn2BQ5rhi3WYDecbU1XA	77	2	1	1	79	jwN363KeQsBHRAotEK2ngC7NcnrLPUtXEKG54WChkWQSmjjWnFj	78	110	1548878620000
79	3NLvynFHCTMjByTtUMcuLDjsHfPP29HupyA5XrNGrKpm5JKv8L9f	78	2	1	1	80	jwJrftFdmHsbEiLjeCQbKXke5NSMVR6Y1HSeq6KgBnjPZQ2V4cY	79	111	1548878622000
80	3NKpgWyTVkiaVDWb2u6c1vZWu1sdzHVfpNSnFhLUrtExQzDXxeHb	79	2	1	1	81	jxEZuroHy6YQrc6czxJFvAANAbgeNgzteESztXTz6nMuFo4wVKf	80	113	1548878626000
81	3NKLmnXaTYbULLuVjC2PhH1hSKKqZkn8qR7LmMr6bAj3eLdgb2pD	80	2	1	1	82	jxMt5oqip3S73LQMuaEMAzqeEL5kvad86DoXbJF2kcP4nWfWiMT	81	114	1548878628000
82	3NKHMMpKVSa2g4BRYrVszdH62ywmiwFKyH6qTuRRjuCRFtRcmA82	81	2	1	1	83	jwaQdkj4Lg8m9W2LmRCQaxCtZ8UdqKPUkmLzqYeCrSjdiV31Dpm	82	115	1548878630000
83	3NKPADiiunphZKDm6Nj8B9vzznjfDvLv5bj6sEh22NAZTgj345k5	82	2	2	1	84	jxpxQGLWaqahNwgeSWh1CRv5iCSDgjtcYLYyvPU8ub6y8Cuvv4S	83	117	1548878634000
84	3NLMNzm45AVvu9PsJzhtRAXJqG51sihu4v14rw1Zx7ath6Kn4W4L	83	2	2	1	85	jxkVXRbpKRomjRUinTscumgB4bRvBFXQqYT3pg63HAkqMKGqZfy	84	119	1548878638000
85	3NLP5rDQDFJPk2XKyLeUmgaRZoPMyFbpf1HuvEmvQcZNzivMufHT	84	2	2	1	86	jxBAXKUAo63KSW1jXZo9GydRkUfZHAxWkS4wNDpkfe5SxoScgvS	85	120	1548878640000
86	3NL6T83au9i87fpRQL1DwDgYqxtfkWABTiC2Surg7wVV12pGnXTE	85	2	2	1	87	jxscdhXzKNMPb3WxdrPnhXowGTeWxE3MqeTqwjAoojoYt2DaaSZ	86	121	1548878642000
87	3NKyspVHixFr8ei4nUb3ViTaXvzj4XpoBz52k8m237R18Xko2Hn2	86	2	2	1	88	jwPpYv5H3toa5f8kTuU6uwjvg1p5K5y2Y2cyCXcccfUz9CRgX9V	87	122	1548878644000
88	3NKMGiQqjE1oAYRnyB6bjErzFJmjPJ3PK5qBGFpgPbiKvRAJakvJ	87	2	2	1	89	jwAM1QbGCTH83yKvwdTc7wLfB5GWgqHrcfz84fGjNnKB9smnDRR	88	123	1548878646000
89	3NL9aG4VjdG6Tq2AiNj885Hzsyc1RURj6fc6XEEa1oeU6NiwbsxF	88	2	2	1	90	jx6qGd1qhqCwLv4v64Ffy58kQx1PNpMQuhvRrmPwiLXVhXQDkEm	89	124	1548878648000
90	3NLqjH2EpuWdfh8EF7MT1TKd1DU1nTvhRyY9Bw7XSSqX5kk1o7tv	89	2	2	1	91	jxdGRyB2b2x82kkQ9Fc9cKbdGWaRn4DUTrfsKm54vM6EjDfjZ69	90	125	1548878650000
91	3NLqHR2FFtUNt8JzkXZhqNDPxPMbXnc9kWBo7oVpsayRxm3VF2k1	90	2	3	1	92	jwoRv3ynC3AnbDJviLsoYtMdkkQ1Z5bubyais85q4WrQQ1vAQBJ	91	126	1548878652000
92	3NLfAkv6DzTvNg6B8xJuav1NWJ8TTiyJJhVN3zzQiWdFEyT5zrxd	91	2	3	1	93	jwSHJ5KecGJQ3ND7J7mWc3adaaqegkFu8pUiXAxGXfiobkheRWJ	92	127	1548878654000
93	3NLuujtCTpvEkJytH8dvoh3NauESWt5HDhmf4iEE3SuUPLR8QVAr	92	2	3	1	94	jxhtM78osfFhUtGLgUsyfu5TZJdzbEtxuWgx6WKXGBMMKrn7aqk	93	128	1548878656000
94	3NLd37yPBdvwsXQDNyCbShv8F7Q3zJyGz6qRBe8eGC1bakTYkcc1	93	2	3	1	95	jwsnw6nyVTKw3uDDLLnXGZWWD5SqEQ6tNp1k5L9uunEMF7ksQta	94	130	1548878660000
95	3NKUpuECXyixaqSRKF9qdrFe3J6XUdEiZf45xGhJLSA1ajHFecVi	94	2	3	1	96	jwzD2zLpPsMmcANiMzzGkYURhgVsEG9H5pa1wsEXNYK2QfbY1FK	95	131	1548878662000
96	3NLkqTqk3MYJcXAPHjaUuG2fB2kFXYcPAPD8R12vF3DgVFA8WM7C	95	2	3	1	97	jwCaYXsng6KqVG4B2V8TvDgXjhbvEMSK2bu6e2tXZHeGB2yTxEo	96	132	1548878664000
97	3NLnvvbWEPXntEvFTSyJYDur7NqpjgoNkbBBFrGAFa4LE9EyU7xF	96	2	3	1	98	jwGaCfKU9QuEGgN7XcX1phSycK3hiM58JEY7MMH4a7MYEgaBVWz	97	133	1548878666000
98	3NKVquC2MnhqqkLGUhVmENwcnvDaM6SjRtfBF173DbbLxrntjf7H	97	2	3	1	99	jwroZaVZhnn7tRjX57cYrSJRuCJ6oS7zo6StVQAFbYnpxGpKpdF	98	134	1548878668000
99	3NKPunbwPQ1wVu3mQMGb4g8k1EAPSHRjoqMD6DmQwssiPuQNbXzB	98	2	4	1	100	jwRWFXtwaQyAZr8QWnNQ4v1bjSeLurjmQa9ds2vRGrCTMTJdMcR	99	135	1548878670000
100	3NLa8RWyMx8nEXAG1t9qL5ZNMoPnErT3Hv7ZAESxMuMWdXX2jMQL	99	2	4	1	101	jwbEa5dKtqLBfaVEmD8Vr3pZ1eQR5Y9fwNmvBqrR7X7BzWwCDmX	100	136	1548878672000
101	3NKuoiwzx4rQDqiTvrSUaN1jR2ZtRW2LKzaA2Sorbc6nhHNSKKdd	100	2	4	1	102	jwP1iTqJNvZv7mZPk3JVE6P5CLhcm5AE1CLz6WrBSCzS9eqw6t8	101	137	1548878674000
102	3NKkmR85K1Xq61vgBHzt4L6TCm571UBZgeEnZwrzkaB9wKJ1eVYN	101	2	4	1	103	jxfpjwJ8hA5fF9F7VSRDzDMmYPA6uh3bSwFJrsWxkr3BRZ8WLSz	102	138	1548878676000
103	3NL8w6ZT1PC781zi5qAmdLdX4rjAbUb5nKuHHFyiUw8sdQHg8oio	102	2	4	1	104	jwtuZVNhFeE5kvX3hG9i54o8kQC2x4exL8Wki3mJiUBBABVtogn	103	139	1548878678000
104	3NKL3onNeifVWkeLD69LW9ez93xcwcT3t6uYNkPrKt1jfo2W4XAM	103	2	4	1	105	jwYBvb7uMEVXC5kMbPYRNfBHi3f3qCr99e2k29fjnQobQqNd4cr	104	140	1548878680000
105	3NLBKF33ijsKRi8WJhkQ7Bfs3QUDutPPxMztPTr3mTCXTiRZELCU	104	2	4	1	106	jwX2p4dCRSu4uDZirKe1TaUrrrFmgAHUfSu1MYqSzmAaR6T9Kyp	105	141	1548878682000
106	3NKQ3veSEW3uVjTsCjdZ4haNz4FMEiss3hptBffq4rAjzy4VSN3t	105	2	4	1	107	jxbY3Cwxr61MN2XVAxo7W5W2aZoJUKu1tNmbtnkdtK5kjMGRtmJ	106	142	1548878684000
107	3NLeei6BoHss9bs7ZtobaZSFUcXpv7anGKaBsM3XpzvBfscztYWq	106	2	5	1	108	jwvp7xGMthjAsm7gbPWLkYa7TE1WmmfnWjDqgwfzgF3jBhg8ysh	107	143	1548878686000
108	3NK77cSprK92FPoeKfWFxG2f1TnBfYWqa213hdQtyKtFFVBbP26T	107	2	5	1	109	jxKofofxncJxnHPr6f4AFCe6w5apmSFS4hQq7FG5v9bDnU9bk9z	108	144	1548878688000
109	3NKaE512d9Fy7amEkvTBzNUmi8H9BYRvPtv1a5q1wXKTHhLHhrLk	108	2	5	1	110	jxAypC34QESfBfPsv1uKMrqNTA6svRBi9ZEKMFGpcSPoS6GZWDr	109	148	1548878696000
110	3NLkKVBM9awqHNmLYNJgPs7bm5RkxiumNgWZaTBRfPRay1tbu46p	109	2	5	1	111	jxM8bRLDfLJtmJYP1LhsutGsurWqR3QEh8kFGgEeUM7vGuxVQJC	110	149	1548878698000
111	3NLFS1anFh5ujvgJVTUosEPLUqVcyjxZxTwfHwF1jJdPFbEdbsre	110	2	5	1	112	jxVC4RLGGD5TxbZoPC5XswFs642L4aaLQ4imk9apTAEygPNSkvh	111	150	1548878700000
112	3NK5zAcSPvxc3StwKAWdk9DtZ81qcVJQRhWWKpFoiXU9D4WCJFG3	111	2	5	1	113	jwwk6FxyMikjNgYxXjUjWNjsiWpUiHcFwSdzKczBMrNd8Pk3oN7	112	151	1548878702000
113	3NKa3UTU3fUNEwt2mokJyeScTgHdng5sUnUNKUTghuaPEgDF9x2P	112	2	5	1	114	jwoTrcD21rhBBRSc7JTCttmNPd7xxrDcJkYURMuuQzW5QrECah3	113	153	1548878706000
114	3NLjuyeXYkaSAXk9TpqKCWpeaD7C3YBAfxwdwwao375dstTG3eS4	113	2	5	1	115	jwXJhu7KDzBTZYN3pgU7XUZ1rHwe9WqcMckLYaZkFW7psZn1iGG	114	154	1548878708000
115	3NKjS3fLzpVvqHE8aD7AXXnD3i37Q4SaWZxvpR29Rmks6VqAoZKe	114	2	6	1	116	jx3Tjm4QzEGgc2P8Go18oqJtRwvzBP4BmEs8mFcBZdSkqxGb6fs	115	156	1548878712000
116	3NKwUPcHEzm8L2BbS5HvFpTLjeHwnagY8jJNgEh3jVZnBe2miZoA	115	2	6	1	117	jxbhbCf3GHU8D5fNfFQ7V8atro6wX6RTQArxesppSEWBDz52vFG	116	158	1548878716000
117	3NKKMoWh2YVMgcWR8iNGF3gKwn9MPFaPjxczUqVakAfMs69aKcgX	116	2	6	1	118	jwGTmoiTz2yVw2boF9x31gk4qUofF232XAiVA2rgubMRYm1Tje6	117	161	1548878722000
118	3NKGeW5ZgxRE9ZJuCpNyWd1ZbGfFLDwageMdvLGBsNs2vt4wMnpu	117	2	6	1	119	jxk7w7DsFFpxwKGjXndWvcgbjdPkXopy2saihEUKwTqQg7eKo2Q	118	162	1548878724000
119	3NLxgqNzPFdun1zFH2fCYFfeiAmWYSEdxeDBtVTntBqQYtKesAts	118	2	6	1	120	jx1iC95JrksjWFg2Gf18ewVDAa6xJCUnZRMAsqkGrqrtKhwp4Ci	119	163	1548878726000
120	3NKGj8E4rvCGYyYaNYN4PFfeteRhopmx2Libi1XRhZLVZX1BRJD4	119	2	6	1	121	jxnzRowvG8iEPZGKpF3EWpemRJVQf18jqvaA3nnSPQPUA9J1vjy	120	164	1548878728000
121	3NLUv9CUvj16Shhi9THhyPUgEh5T36tAzsNe8LuQ1v51arogEQXv	120	2	6	1	122	jwdkWrf8TRHNFHJknrxejx22Th8hJUYmjzSNpofhFPgKnmpfpL3	121	165	1548878730000
122	3NL6vUJh3a62MjVJ79zcSijBGEaAu2xBxvE1xs5P2kQMW6LtwqKa	121	2	6	1	123	jxbn8fdrUAg6NU9McHvg6MKottuPanbBox2hoPd3LKXPM2WSQiB	122	166	1548878732000
123	3NLmGXfjA2muA3XGVioN5U3okmJuvk2FdBDn2LJ2oXYjERfbSj4p	122	2	7	1	124	jy1i3LdzaD7TjKWr1kpxcpLZRwWSFWSGCzXygvvJgZZYDJSbVkt	123	167	1548878734000
124	3NKi8C2fcLFq8cTAMg7zd5QDTfNzfP86B8oKQ9FQaJc39iJndrAW	123	2	7	1	125	jxZZztrCKutze5GuncegHwVkgSwC1c4vhZxKRzY4CYyYNeVQ7Rq	124	169	1548878738000
125	3NLLMD7LsqFpcwGP3wrPDmgfwhCJR6JDXnJTKhPj9bgCncLk7wLW	124	2	7	1	126	jwYDDAvDz1kgDtwkgCJgeXvcTeTL2zsRmRhdZtxQZk3SZdzMArT	125	170	1548878740000
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
\.


--
-- Data for Name: internal_commands; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.internal_commands (id, type, receiver_id, fee, token, hash) FROM stdin;
1	coinbase	2	40000000000	1	Ckpa2EQd58cbXppykFkzrfd8ZQb23vn2MzygCtfaPqtR9aV6Xb2nL
2	fee_transfer	2	2000000000	1	CkpZJ7G5KeHtKKLRBJqo6aqdJasVLHJ2KbjbXKHBhEm85PrCvWJTo
3	fee_transfer	2	7000000000	1	CkpaE48vckzL3G4YMLJPocazHAXPihgbeVdWVFWTVMPgd19usasd8
4	fee_transfer	2	3000000000	1	CkpZYCRGxbqFp9UpkPvygjNX3chjyfaJt2kK1Ltre8LRUucGwWhFz
5	fee_transfer	2	5000000000	1	Ckpa4JXQvjMU21sfxQdHxpKbq3bcBPNMSss6bPM82EgUgoVY3Nv7q
6	fee_transfer_via_coinbase	5	1000000000	1	CkpaFTp86XXkYXtipU56dbbKH9UXvLzy311pmYUUZxsczYzm8FT52
7	coinbase	2	40000000000	1	CkpZ3DyKUxhuzWsqSJqkdWUi59kkNpfy1WTdk8q9snXwSnPPPoSzA
8	fee_transfer	5	2000000000	1	CkpZi2JRavyWk2p343VrukbJwhhBkNqiNUCXC5eMPa32h3TS9EUJG
9	fee_transfer	2	1000000000	1	CkpZBJJ9qcwbXCMLG1Hw9TRTQ6WKFLKHqQyXph5acegAJzjKrhv5r
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
1	jwcYgfQcGNGigQqUmfSt5XfaHiH4XtoRQKpbkCQG9szbmDcwgAx
2	jwaSZdCZpR52KfTLktpYDk68CQ35FLH2tnuBTMYtZAX7GHVkSd2
3	jx2dzyV9mrwGZPA2xWFRKXjqPPunAgSdWn9HW5gnrbC5EApbJvN
4	jxQNEe4Saxxe6cbH18XkST9jLqpdxoptZkJPeSn6jAgz5yG7Hie
5	jxoQcZkjxEELLmF4jVH6eTxJbi1zHGHBPDyDCJcJQJCyWT2dw8q
6	jwVedqTiu74jJ4RN7LiPwqefJ3rLWw9NTQPivP1REUgQAL2R79E
7	jwVKKNjKv2XBnUUjEPMuGwaQ1mLbC7hyj8bGYMLWb3joHYJ9EPX
\.


--
-- Data for Name: user_commands; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_commands (id, type, fee_payer_id, source_id, receiver_id, fee_token, token, nonce, amount, fee, memo, hash, status, failure_reason, fee_payer_account_creation_fee_paid, receiver_account_creation_fee_paid, created_token) FROM stdin;
1	payment	2	2	3	1	1	0	5000000000	2000000000	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZLz16kmScepi3zx58CteYxaGgcr1fZhvKUaHYnhxA8GWEiYExi	applied	\N	\N	2000000000	\N
2	payment	2	2	4	1	1	1	1000	7000000000	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZB7L6uz56AXZqZveKLjsnR5e7R1jNDa1yFrq1qDfft2NMd7KCu	failed	Amount_insufficient_to_create_account	\N	\N	\N
3	payment	2	2	3	1	1	2	10000000000	3000000000	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZRaakSTrXrTNWHrSaNFv99suZ7MYzaz96dkmLH1akm7whPPZ5N	applied	\N	\N	\N	\N
4	delegation	2	2	3	1	1	3	\N	2000000000	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZG6pQaChiYPErYXprkHG7ADZttXn9BLpEqZE2XTKR711YSvGkh	applied	\N	\N	\N	\N
5	delegation	2	2	3	1	1	4	\N	5000000000	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYa4VcW4S4KZgjfujh4SNLDGXqWqv4oPVCWZbQ6QaB211kncFsr	applied	\N	\N	\N	\N
6	create_token	2	2	2	1	0	5	\N	2000000000	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZus6yoimx1xg4TUUvcigPNW74ENkKRYW44xfZ1gzT52qc1Hpev	applied	\N	2000000000	\N	2
7	create_token	2	2	2	1	0	6	\N	5000000000	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYpxKgqY8MyUe5H9vneWdiBuiDNnHiQuUs7j7knByL441Bnovc4	applied	\N	2000000000	\N	3
8	create_account	2	2	3	1	2	7	\N	2000000000	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa6rAVgdhD7DaMFqmyQs3K8wgu75airt6dhYQbTyZ2GDMww8xAL	applied	\N	2000000000	\N	\N
9	create_token	2	2	2	1	0	8	\N	5000000000	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ98B2pMDHhu7AfecZfU3h5ipSiSjQVXzRCodMCLBJwRKzEjHAS	applied	\N	2000000000	\N	4
10	mint_tokens	2	2	2	1	2	9	1000000000	2000000000	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ6wMmeTupoTKRZjiKTRBkAK2XEJGCMfEa5QzKAtbc6LfKMARjC	applied	\N	\N	\N	\N
11	mint_tokens	2	2	2	1	2	10	1000000000	3000000000	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZfEzwg1UUAwA5unwgcDHc8VNPcr2GtHDhW5G4Zibezxdb9st7k	applied	\N	\N	\N	\N
\.


--
-- Name: blocks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.blocks_id_seq', 125, true);


--
-- Name: epoch_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.epoch_data_id_seq', 126, true);


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

SELECT pg_catalog.setval('public.snarked_ledger_hashes_id_seq', 7, true);


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
-- Name: internal_commands internal_commands_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.internal_commands
    ADD CONSTRAINT internal_commands_hash_key UNIQUE (hash);


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
