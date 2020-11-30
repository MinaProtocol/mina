--
-- PostgreSQL database dump
--

-- Dumped from database version 12.5 (Ubuntu 12.5-0ubuntu0.20.04.1)
-- Dumped by pg_dump version 12.5 (Ubuntu 12.5-0ubuntu0.20.04.1)

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

COPY public.blocks (id, state_hash, parent_id, creator_id, snarked_ledger_hash_id, staking_epoch_data_id, next_epoch_data_id, ledger_hash, height, global_slot, global_slot_since_genesis, "timestamp") FROM stdin;
1	3NKv8ruevWD1yfR3o4zg6UYvTjqgsEesnYcZvzks1v65b7mr4Js1	1	1	1	1	2	jwcYgfQcGNGigQqUmfSt5XfaHiH4XtoRQKpbkCQG9szbmDcwgAx	1	0	0	0
2	3NKTXGHUruGVGcS9B5fWsQ4GXMT3dkYfe2auq983HoHgwJZf5Ec1	1	2	1	1	3	jx6GXW9BeQfA96xgu1nzpu9PmpWpTyeY75yRLDivaHSuXoQCJCR	2	2	2	1548878404258
3	3NLJ2u9GoofNm3NHdkUAqJokjySxNbJi6gYk6S11yN31k1BcMG4E	2	2	1	1	4	jwgom9umDmrSDqYtWFTtVdeJVo7Cju4TXDbXfBCqXDFfHqVMvJj	3	4	4	1548878408741
4	3NLktJ7z8pZQTfZC2cZWBqMpQ6pcW6Zenbf4v5W8FV6ucPZBsEWv	3	2	1	1	5	jxLjfwWh7dmXAnwTwcPZr9LoE9BC2nBkAQETD9Epq9yiX6hVrZ9	4	5	5	1548878410159
5	3NKesThQwsrqhXsH4GKBwnhVXToaFHYQJxSZojZkzwUs2qcVy4PK	4	2	1	1	6	jwaSZdCZpR52KfTLktpYDk68CQ35FLH2tnuBTMYtZAX7GHVkSd2	5	6	6	1548878412000
6	3NKrFmSsXL7xnxLyMc3ctTQpWP41txFbDHQrPr66BUztiPyLXr68	5	2	1	1	7	jwzMT1jZ88ZZuaGguf41avKCecuJ9Gr1o8NtHX26MBUeMuHzvV9	6	7	7	1548878414000
7	3NLXTj8hyzfJWcfk7Vdgp7babGjkCpg7YUzru22Vr46aTic6pjbS	6	2	1	1	8	jxWxJa9DzqCRKtvrvr5Lc4gpAkDAfNoXZTeXHQcEh1EVf7t7dfC	7	8	8	1548878416000
8	3NKu9iuctC6Za8CeMJh5Lwna8BCAYDrYJo792Mb6a55bW9dusTVG	7	2	1	1	9	jxqiERhK1XWkrLrs7dVB3hqKt1YsPdzU3D7QbjMoyGw32p5Tn2t	8	10	10	1548878420000
9	3NLWabVNBCvzom2h2UCWzhTknFdd2weFrEJPGjtzRkLZa94dqpjW	8	2	1	1	10	jx4Tj6TKacRuZr9TfgpC6mtpFbuQMtAJLFHsFdEadYnYr7ZpBin	9	11	11	1548878422000
10	3NLMARiCyGBB3xoiq7z4W3HMuWvVtgVkypk5o6q1aujWUMdKo8Qe	9	2	1	1	11	jxGj9SUjfNtv9NUmq4VwMghWmdrBdbj7uSgoCUQtYysASbaPmM4	10	13	13	1548878426000
11	3NK7P7Ddo9hsHyYTdQNsbrVHtjY4F6egMFoifK1hris9SgHVRed9	10	2	1	1	12	jxQNEe4Saxxe6cbH18XkST9jLqpdxoptZkJPeSn6jAgz5yG7Hie	11	15	15	1548878430000
12	3NKQWsGcAWbGTYGRyXea52b9wK5mbYeMHFj6rX81DWbuZyrqBFYH	11	2	1	1	13	jwB3WkGsSFBZ4srzJaDjDsSypfYUHe9MUC5yYKkE16x1ewxu4hM	12	17	17	1548878434000
13	3NKBnJPLLjrx91Cxy6CNJrKDtXoxdYnskB9qoQ2nbFDGCH52PmM8	12	2	1	1	14	jwAffXfTcjUxVqqL5youbyerBYqoVdSaxdmLShw8Nq3qu9Pj7iA	13	18	18	1548878436382
14	3NKs2EGqcerTFQc1eUK1Bs4L9RVtce2iUN1WfdbK7qFgRLbiAPSk	13	2	1	1	15	jwnaxuamuEdiS2YxKumdMWGeTsDSzyqhniqRmHWq3pbEBSXCX54	14	20	20	1548878440000
15	3NK6fqeLFKpkTdxVqwKpsygBNCEnJsxmp6f2coxs2rBfLMDs5uEX	14	2	1	1	16	jwmh8ApSJsEPBcjWNGy1zxm2QnNwrxcgvpayBR4ULxwjp3RUB5d	15	22	22	1548878444000
16	3NKeNpFBz17SHLstTvfhHwpJrbJ5eYEbBbbHr3V658Sd67Fd3dQ8	15	2	1	1	17	jwAHPEHwmTgf4QBqFB488zWU6LvbXKggmBgpSUMLszsXD6AYPm8	16	24	24	1548878448000
17	3NLgyku5eBySJdndRbftcd3RNmS8DSFoM5H4eRFLCsCfJVuoCy9L	16	2	1	1	18	jxdaifb4vdvu2tgHbjq4uXLA4ZNKxHL3TcptszyDj9M5YdEYkyw	17	25	25	1548878450000
18	3NLnkdsabUxD1VpAn8XFmyMdn5BPgERxXrMpjLmabHwpe1xGqLsa	17	2	1	1	19	jwmUqBV8V4a2n9EMnLzveYZTEhCmbTsLAzgz8WorSq9uwXaYD4Z	18	27	27	1548878454000
19	3NK5jd6zqT9T19ChxPjLs7DYGeiX8QxU6KxhttLRUThkhLWCxtnh	18	2	1	1	20	jwVedqTiu74jJ4RN7LiPwqefJ3rLWw9NTQPivP1REUgQAL2R79E	19	28	28	1548878456000
20	3NKkm71kCx9NZbjeLnmjX4DN5G4noxeVKwaNyyQJYcCb4nKeMEW9	19	2	1	1	21	jxJPjC3fPSX42z1abYmM31reScnQLy3ec1Zf5U62aWAYHcfeQsq	20	30	30	1548878460000
21	3NLk8PtBvWbx4T5MPTn7pjWZhWAY1CdXaxpGtVAgvUZVeU7GJQ2s	20	2	1	1	22	jwayGJncpZ4jQ9SyztfZsQi71Sn4RYLDuzWbuABagTQ1YGBMzNV	21	31	31	1548878462000
22	3NLEvQBQLaUQ8MJwT1Tp6SWQTLjVSZvA4qfn8fNyTNZ5dDUE72s2	21	2	1	1	23	jxcGmfoHXyT4Zkyzwk32azdXpw5hWcHVuWi6ukvnnVbgtrz5dWt	22	32	32	1548878464000
23	3NLmfEuN8GEyVhE25U4zWkknNmRCo2VjQE2cUE9oeYXdoWRjaGbr	22	2	1	1	24	jwXJ2hgfWQVGkGqGg7Ci6BCeu9U1oBsrVAtfsfBFhbQgndipi8u	23	34	34	1548878468000
24	3NLciHqodb6WaC656pMAktx2fwNc2fB1Zagg8jfGYcAYurtnLoy1	23	2	1	1	25	jwQHeeFbAgx7mFwfSJ2YQF653ES6k7BmbkFRizcqNXm36bmaQVs	24	35	35	1548878470000
25	3NLtcAxAa856MDgyJVeNNriCUnYg1EkK95sUhusrW9EGEehdiL5x	24	2	1	1	26	jx6DrasMUPXcn1EiRQcsYN6g1RU5h8a8h63YxwT6chg2rXwER6E	25	36	36	1548878472000
26	3NLPwP3fgw125BpxS4KetfKhHwrs4hYNUbdn7hHWJFc2eQS473K8	25	2	1	1	27	jxaMEdTQumqsBEWgtJfAjgxCEPnhZcCeMM2fQyu14HmwknYKPUM	26	37	37	1548878474000
27	3NLvQmYmP2BwG9ftrHiuiZTEypg9eAFsUs6v4RiWFrW8QGayL5DZ	26	2	1	1	28	jwVKKNjKv2XBnUUjEPMuGwaQ1mLbC7hyj8bGYMLWb3joHYJ9EPX	27	39	39	1548878478000
28	3NLZmDncYXTwGhmswEnqGDbn21y3LnoqAtAbz7TDPBhwme2qVU9Z	27	2	1	1	29	jwjarc214PcDvBTtZTw5WKkAtZXuY1PH1D1STTV4vmmgLB3kdpH	28	40	40	1548878480000
29	3NLGFVEK4zHzHBGPah3G2oZXu7KmLKpKUW6GUiHVLgft9HpJcKFn	28	2	1	1	30	jwAfixGx3d4Z4dExbsNRiNA1Ti2MAh3X6V4rjzfjUKWxK4UsDwu	29	41	41	1548878482000
30	3NLqLTyDpHWPdyLyDVU87bb64t78huifddtk5vbMpkkQnXWhKhQm	29	2	1	1	31	jxf3iAaQaM82KdSfN9q1vaQZH3eGBy2SBdYGy9zsWbTuHcPAQGr	30	42	42	1548878484000
31	3NLtekmr96ftvQJzbmia6eJUz49hVVHrjQAx9d2Wp8PaU4gtziTx	30	2	1	1	32	jxVWXwvKvHAM4kMeojndKiVwMyD3AJ1Du6G1jWgcYChVYXZz8RL	31	43	43	1548878486000
32	3NKQLtSfgp4EvmTLD16rkVvpY2aS3KMPnRGLNfR6UmqdXc7rEuW8	31	2	1	1	33	jwkKxtTPjDGj8zpcPn7XgnDe6Ls4FTE5JGAH51WmdWLbpCLg7yL	32	44	44	1548878488000
33	3NKtSyruK3RrUG2D1uM3b5Vb59HQ4WtGmYZTFsepuomw2THmwbFo	32	2	1	1	34	jxNJADyMwHBVWJy7QrtaspxuvSQ97H62PWyRDWq3DrmgpqdrWuC	33	47	47	1548878494000
34	3NLXmVL9y1pnMNCwxE6hQtH4wcxmpmfDspZBSRkvcpvpVtpo6HtC	33	2	1	1	35	jx8ahDts7YPDJyt6rAPDi67XvApnbkmMCqyWJDbDotKxMWxCwH2	34	48	48	1548878496000
35	3NLhS6sc5sWNJHjwT1yHaPY2J8wF33rppbbQLZbf7wL2x69inctz	34	2	1	1	36	jwsk7DnMSpofJ7YGKw1HdwvqXFAfYJxU3XoLp1J3GArgkKoQLiu	35	49	49	1548878498000
36	3NKRaPoNTdDwRBxJKmGuBVArRFJsVDLx8H4oXVhf1N32aayCwJMj	35	2	1	1	37	jxUfMKx1bW3qLvs5NSifJHuyStdhM3f1CV27xnTeWmGZC4fXQT1	36	51	51	1548878502000
37	3NKVnsG677EgLCJwR4GajhoFBhUsveDWaT9gi2JK5VCqDAhQUVM2	36	2	1	1	38	jxT8S6wGx8znJ5Dxug3YHVSHRE2UtTZ2wDgHcoC37wZ7uDS2CzY	37	53	53	1548878506000
38	3NLE4nk8NCa7FBx5Q48iWM4SQQwQAo1qcARAwFd9vog7VYtSQrVJ	37	2	1	1	39	jwpmLkKssXvL3i1b1gDHhqY49RF6TZTa3oW6HYJByM113KA7KAY	38	55	55	1548878510000
39	3NLa1SpaCk4MxvJbPt4cMzP9Tw6g8LfNL7HXNVoAq3MBtpNY5meZ	38	2	1	1	40	jwyBDG3BC9xJarWje1QGF3wgdVGmgb3UzXZBDiX3uxjEpuoRsAf	39	56	56	1548878512000
40	3NKxow5CfvyTUL3pGpApfL18Cz823byQ6HGYEVshn5hKhLS1fJ2w	39	2	1	1	41	jwiFT24drN34W85GKJpkaGGTuuKVuxL1kQK9HspnzcnrjdbqHhq	40	57	57	1548878514000
41	3NLK56AZnshPvwPRH9yL39FHdqRe6Kkxu1p44Xgzp8gKyRJXE6AX	40	2	1	1	42	jwTePcxmiydGpLQpY8pqkLPjWP5D5tWcf4rZEq4i4xMF2KSJ1aT	41	59	59	1548878518000
42	3NKkHVCQkDPaUW2NgwE8DZTjTUgSLqBXdXAaUMDkbE8vA9sSfxNX	41	2	1	1	43	jwNLPFH17Sge9Z1YFUW7uTJQQXW8YC1oxeoYXX9rvZjwqTETQxu	42	60	60	1548878520000
43	3NKRymrojbDKgTiAjWwDEM2e8jH9Nm3GHsfYbfEMDNZy2tgteuzv	42	2	1	1	44	jwK3PpEBUVZyxLPFvwQrBpjW4u7CLFwf7Wug1NrLSBPqcVkrFZa	43	61	61	1548878522000
44	3NL2Fugg2DR92CtrrJVbF3Ea5aBtBfwQiF2DSZBLfWqPCXnYmAvX	43	2	1	1	45	jwA8mePeosmMLBEs6KRZRWVWpZkCxFHjLeVdwi4mN7vez7mArsr	44	62	62	1548878524000
45	3NLef2rEQgceG7PBtVhCkWLt9ZE5r6ohogKkPQ3ikrVw1Jb8YxsX	44	2	1	1	46	jwdcgADg8qQYbLAmnv82ZWY2v11SREhZudN6yigaUNyvEqmwWPH	45	64	64	1548878528000
46	3NKgHUNdB5Fe2N3BsqbaaS9uxm3hTaDEPDHNvHd84q8Xsbqp6UJR	45	2	1	1	47	jxNaX3JWxvLY17BC14uQUs5JCGK6hzyxF7hhqufvLppm4PW3YxD	46	65	65	1548878530000
47	3NLTz6WuhfvykzGkYyLq8taM3Gno7HqAXCPpqvaPi6GrMzthPFCX	46	2	1	1	48	jxvMob2LqvHBBawf5dtxNiAHDJ4GM1reZ5tbXeCEbqdfCbKifjp	47	68	68	1548878536000
48	3NKt5iPga57ZA5aaDN1RBk5vFtTapwNwuM2Can9vHPkunrwScqs9	47	2	1	1	49	jwubgkcLEMP7rpvQMK9LHyGcWBixNUCaP2UmLiFLH5Qg9DKcpGx	48	70	70	1548878540000
49	3NLCmopbe8hQZsrR1kfMD3PrE5QdtUcnUqLsbK2iDm3RnZh7iPXx	48	2	1	1	50	jwJ5o9HZNA8ohUQagtCJqmQ3wRMNyrBgkJLmDHV3V6yH7TrxfYP	49	73	73	1548878546000
50	3NKN7FWRE2Uk7joTp5dzBL82wKekptvNMDZLanQRMGgLrtNW8Av8	49	2	1	1	51	jwTHLCgKZ6QzwdajkUirJwhwoT4iwfd6de5XBmopZ7dy9s5EBVA	50	74	74	1548878548000
51	3NLFhybV1pWk6LwzN5UxcRmE2AQ5Rt9pb5Mk6UjMW5j67668sRRe	50	2	1	1	52	jwQRWVcJBR6dZvyr2sa7d9jvbi6VEwzi3j3aP4CfQUizNSu5SFf	51	75	75	1548878550000
52	3NLSFmev1WwQNF3QsNKACHs9ySiD6YYS2TvGQFXh1cuPM2AoCrCw	51	2	1	1	53	jwUBLFBbqGDCq68hYWQxLHLzTxfvGdD6vRJcTnqv2LomE2Cg31F	52	76	76	1548878552000
53	3NKXnx4TFw8X7CkESHeiP1Dp3qmy76Vpip7f1CRuMPtWxQu9ayiV	52	2	1	1	54	jxdbmhvqE4VwovSJWg4BfazGjRbrEy8ejawjZpinjL8sbnxxLbZ	53	78	78	1548878556000
54	3NKrs8n5as287fUoSLEhzcdo24piJPYbcUi5pZqNxZSv5jDkdzQ4	53	2	1	1	55	jxu5fbEhQZ28RXoz1iAx1bEf2S7HKG3BCEhDDMBZVPyWwWyoYFW	54	79	79	1548878558000
55	3NKbKxw24Neib2XbFzMmXpPYXSW7PzhW5XFfe3TwAnun3iLoCGJv	54	2	1	1	56	jwc1xvei9NoByP9aT7nEueeuRUFTuHtuxR2jxvpJE5U2vTXEChE	55	80	80	1548878560000
56	3NK79cfsutfnK6ABJ6qmCt5DjCg9VfzJuyTy8Vr9SpULqQrhKjRN	55	2	1	1	57	jxq8uq4K2hjz3BKEe5VBBgMWJKcAvBTtbbvQ6GHCxRpHH6Xb8Vi	56	81	81	1548878562000
57	3NLAyxsv3Fv93fbayVSKEJ7D8zEFHCtwbaR2JuA9dF4e5C8Sw1vE	56	2	1	1	58	jwUSfyyieVg3vL3NyieZ3NbZgwU8f98y9c2mEdwHmmvBucVJKqq	57	82	82	1548878564000
58	3NKNwVGvBg6zuJw8bQ8skxxmvVZ5tzPeLLwzguGA8HLAHSmEcxoa	57	2	1	1	59	jwNzE1iNLLz2nzWezGVedGrjD4dL9gxAhfMgWd8zu6ovxCf5uZZ	58	84	84	1548878568000
59	3NLwKEojM3fHBYELZQwNBCNiNMak2pv4Q4oG1wNhnw74j9FNx69s	58	2	1	1	60	jxSzqaK1Aj4YgGEYhJa6cyoQSKHHvw9nTPWuVLmehqTrhxxo5p8	59	86	86	1548878572000
60	3NLgXPGaw3afzXngDTA8vJMy5sPLgZjqForHknj1PfEh3PLdVVF9	59	2	1	1	61	jx8YQrBppf4BWUjiCK2fVTKAiPWVzDMzdb4VC7gGtiERQx9oD3p	60	89	89	1548878578000
61	3NLmMs7yJ4afkxzUD7RikSybN56LJXy5f96SA1io14NXn7JgFUJr	60	2	1	1	62	jxtVTe1mwG4D7vUwSPN3HCXHup7ZQBXF6Nzo1N3fAnBkT9gXk13	61	90	90	1548878580000
62	3NKvvmUjQpRNTePnEs7cKUsuaD5CDqb2zVSvRV4GotDsi3sa8GL8	61	2	1	1	63	jwBFp22dtesijvxJK2JDy4pRiM7HRsRFbHVHA3FEEz4puzN2SHs	62	91	91	1548878582000
63	3NLZXMBHLJuSgRYnBxVDbo5U8R4P8aJrcQWBsUh6uwKt3fh3gLcK	62	2	1	1	64	jxYsMBP1LBQJ6yCav1qV2rnVnnvziJYRmrRmF7LRbAfnA7FyQ14	63	92	92	1548878584000
64	3NKZC3cMqpKToKQ34J5g2mt7WXGuWGwSa1VvurrrDB6SEUFzH6Jf	63	2	1	1	65	jwBLDgUE7291VKxZhSoMEc5woYV782dUwpDC6YpxrN8X1YFFAiF	64	93	93	1548878586000
65	3NLsZWXkVweCYVdR9ZwA8zgaPmkKxmeToQ6eR2fr5eFLSqBStJ47	64	2	1	1	66	jweRFoP2KzyxgBxJLRzdZPH1NaTQ4QsYDYVCYL6irKUnHc9xUYu	65	94	94	1548878588000
66	3NKM8tzUoVcRKmxiqLUP95YJVY2zyPFp6iCVUcJUq9HtmZecpMyc	65	2	1	1	67	jxHH4pVGC8pPjLfGioZzT6xgxbWbDogK5UnvKWqsVi9xuWoGUsS	66	96	96	1548878592000
67	3NLVYxXW6SE57BBqFGSJmcxXA3LigcW75NPY954ndPXvJwpvpbqQ	66	2	1	1	68	jxLC2uZBq7bny3DCyu49FvyfEyoMYxyJDYB3as8E8mXkhVMhH4B	67	97	97	1548878594000
68	3NLForptdN6wnvi8Nb2RaUNnKE4pWKYLybwsuMGZz6qVu1STZNNj	67	2	1	1	69	jxppUvbYCVFYeHx2deSpuqUjR9HjoEt4aDmq58G9PE2wiTX7NDi	68	98	98	1548878596000
69	3NLwFxJhBwWAE9d4kfJPr4CvnVNZAfQrjLjq2VCk3iVXBjGvqxv3	68	2	1	1	70	jxfdGQivBSq42NXtf3CoRtMdso9vM85eSKXfdzJU8tqy7G3HJET	69	99	99	1548878598000
70	3NKJdJCaSpo5SKDzmkkW6u4mgPemEX3UXDpQ2mzfFf92Bqy1Tq1S	69	2	1	1	71	jy3LTHYmToLHNnNaQRP3uw9ukgqSbEPVs7FndDHhKc4YcQbycoT	70	100	100	1548878600000
71	3NKj38KTbLvXvQNv6tY62SktdVSZmFFuAZcW1T3RjQS95xMj21wa	70	2	1	1	72	jwxqWNbNfuuCd9oBvXZPYqHJ55R8ofW7Zav1RLYsnVgUwuLjtcD	71	101	101	1548878602000
72	3NLC74NguE8C4NfRgRM2hFBMn1VrwFLh7qh1caYPMXvrGxFFQwtx	71	2	1	1	73	jwUDseY6dgyPY9s3qWyQUmoLrAuLcDwsdn9FqF5FGxv5RJanv6P	72	102	102	1548878604000
73	3NL9w863afGFgHHEP13Q1NeNVHz5s5SHoNKcWmyGtCJJDPyaYu17	72	2	1	1	74	jwgACJvp5uF9oqAaRA28xEESe1Q4grrfBSgq4NvAYU7GDTYgVW2	73	103	103	1548878606000
74	3NLg6he3jhkKGQJfkRy7nAnoKaaLt1bDoj6ZSWeSArpKFovZbVVq	73	2	1	1	75	jwQ3VZ9a4gZTuW63iy9WZUgpvvWuHN5aozuRvQLoK6kvsTaGDto	74	104	104	1548878608000
75	3NL1FhH7cETTwbp92tnKuRdkWi8Ec5xCXEqBcfuYzaXifgUccBji	74	2	1	1	76	jxdFPjqfFaVrJ6yktxHVkWWk7JpUNKx7cmtrhvvGFMTG7bYgGkA	75	105	105	1548878610000
76	3NLmNJYSZZeNczDtMGFWczKG5MBTDJis2MTuJM716v7cY3bgqW6o	75	2	1	1	77	jxa5hjnJwvwcdf5VsbdQ7g4NXu8fMVuVryqV3z4Xc3bxSSYkdNw	76	106	106	1548878612000
77	3NLXAq94vQ974aehcqn4hWCJ2CrnZ4ikFqi6hA6imfrV3afVaHjd	76	2	1	1	78	jwBbrDjdodE2KFNC2k91nuDTVVPbsA8JFZd6zGFBbYcdM4oD7qU	77	109	109	1548878618000
78	3NL7ErhmDhV1Seie4Pf3npQr7tXHAuqKEmyeAxCDr2GuoKQmtG7T	77	2	1	1	79	jwN363KeQsBHRAotEK2ngC7NcnrLPUtXEKG54WChkWQSmjjWnFj	78	110	110	1548878620000
79	3NKwLvMWiTJwutjjeZ4gA2iaCr13qACmZ5cFBoB6HhP5otgn9rQK	78	2	1	1	80	jwJrftFdmHsbEiLjeCQbKXke5NSMVR6Y1HSeq6KgBnjPZQ2V4cY	79	111	111	1548878622000
80	3NLo64nyzSfEUrSkAp5JBJvwEdsEpYbpnbvN3pjQnMmjCELqrRvu	79	2	1	1	81	jxEZuroHy6YQrc6czxJFvAANAbgeNgzteESztXTz6nMuFo4wVKf	80	113	113	1548878626000
81	3NL8ZUsyijkWhAE3G7da8SFEZVQS3Xnf2jwuDmxEkiNf8ny9AhYd	80	2	1	1	82	jxMt5oqip3S73LQMuaEMAzqeEL5kvad86DoXbJF2kcP4nWfWiMT	81	114	114	1548878628000
82	3NLZkRwqGhDxMu1P7AFUieX7YQqGRC9T1yy77ZvwQtKV7u486Xfc	81	2	1	1	83	jwaQdkj4Lg8m9W2LmRCQaxCtZ8UdqKPUkmLzqYeCrSjdiV31Dpm	82	115	115	1548878630000
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
\.


--
-- Data for Name: user_commands; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_commands (id, type, fee_payer_id, source_id, receiver_id, fee_token, token, nonce, amount, fee, valid_until, memo, hash, status, failure_reason, fee_payer_account_creation_fee_paid, receiver_account_creation_fee_paid, created_token) FROM stdin;
1	payment	2	2	3	1	1	0	5000000000	2000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYsbZv2kfUxTLy9UcGCdtB5NBepcLr9Z5eQzx2QY7Agm4oUDHQq	applied	\N	\N	2000000000	\N
2	payment	2	2	4	1	1	1	1000	7000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYs2k5YsKejYmtUNtmf35n8wrYoH3bDrNUfFrmRa85woFYr4dac	failed	Amount_insufficient_to_create_account	\N	\N	\N
3	payment	2	2	3	1	1	2	10000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYhTJMv6eqni7FxfGJi7C61y5GusXkuCRXyWizrPpH6xMzBpoCw	applied	\N	\N	\N	\N
4	delegation	2	2	3	1	1	3	\N	2000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZbSKUddpDwEVL2pKbQ7z8JU32cVHizqQLgNyjqY4YTHY47446h	applied	\N	\N	\N	\N
5	delegation	2	2	3	1	1	4	\N	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZmDDpMVWMmUxbT3teFgDWkffXxni8ELUvitxGhKAa3NbhtJ52c	applied	\N	\N	\N	\N
6	create_token	2	2	2	1	0	5	\N	2000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYuUWK3FxM67ksmnL4BHntn4Vtxh2dVqTM6zBsia1wPCUQdroEF	applied	\N	2000000000	\N	2
7	create_token	2	2	2	1	0	6	\N	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZJkt25Rh2ngAMso4JwwEBmnfQSVyE8D5x7sCtrYFSpTMWuxUVU	applied	\N	2000000000	\N	3
8	create_account	2	2	3	1	2	7	\N	2000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZKd8iDLMGvtMdMDWHkALiFkTThvfQQhazWXY3x2evgrsdsTX2t	applied	\N	2000000000	\N	\N
9	create_token	2	2	2	1	0	8	\N	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaCuuGk9vYmxLaVmzmef5Vru6Tq4fctRgHG1ZaeCNbbe2eB71k2	applied	\N	2000000000	\N	4
10	mint_tokens	2	2	2	1	2	9	1000000000	2000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ4R1tyhWMGK4d7XCE2jX8A5HrWgqYMqfEBaoxV5YaYvzTyRzhX	applied	\N	\N	\N	\N
11	mint_tokens	2	2	2	1	2	10	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYWLNytujuWDFgZ3fbmcNk6DVNyfC61AnkWk2kZBCZY397TotgP	applied	\N	\N	\N	\N
\.


--
-- Name: blocks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.blocks_id_seq', 82, true);


--
-- Name: epoch_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.epoch_data_id_seq', 83, true);


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

SELECT pg_catalog.setval('public.snarked_ledger_hashes_id_seq', 1, true);


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
