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

COPY public.blocks (id, state_hash, parent_id, parent_hash, creator_id, block_winner_id, snarked_ledger_hash_id, staking_epoch_data_id, next_epoch_data_id, ledger_hash, height, global_slot, global_slot_since_genesis, "timestamp") FROM stdin;
1	3NL52BwYWhu6oHPY5YAWsUmFtcuCJJ7BCifUxgq2Wo9CwNdgiedA	\N	3NK9z26joBvSDZswiLVjHp3Y3c9t4vq7P8H5JCk4QpSLL9sXMPMb	1	1	1	1	2	jxg7fB9SZMZLcuhLfHMwGaPFUAn3Bg2MNadrFckhwHqT371AUvL	1	0	0	0
2	3NKy4mR3X3HPrFFmyBetVDPomBkLphRNdMqbqzKUdwrp8iU9xWsE	1	3NL52BwYWhu6oHPY5YAWsUmFtcuCJJ7BCifUxgq2Wo9CwNdgiedA	2	2	1	1	3	jxxQEzqG2gMbUMMd5aA524RDae5gdbyu4HxBbBe8LP4WtDafPQe	2	2	2	1548878404000
3	3NKBL4ihFhjWJkD8acDHoaMt9c3Qf3v7QeZTTwPiE7V2hEj1FmY1	2	3NKy4mR3X3HPrFFmyBetVDPomBkLphRNdMqbqzKUdwrp8iU9xWsE	2	2	1	1	4	jx1XsErm9KVpy9rxs4VEEsNNp3FSAjMctkGKkHkZuuvo9DTUQS8	3	4	4	1548878408494
4	3NKVEFVUMWi4uAhFL1jiHXLxhhTkfzakoREh5ufCzdrbsuBsT1dZ	3	3NKBL4ihFhjWJkD8acDHoaMt9c3Qf3v7QeZTTwPiE7V2hEj1FmY1	2	2	1	1	5	jwpwdTERXHyna5pjvqQZhj8PSEF89rsMAxuqUJep2JxpEvYn52a	4	5	5	1548878410000
5	3NLsqpFCaFPqjDS6vdYJo7GuywE9TMDZG7HUezhoyh34XRsGsvxV	4	3NKVEFVUMWi4uAhFL1jiHXLxhhTkfzakoREh5ufCzdrbsuBsT1dZ	2	2	1	1	6	jwZG2JKgeNfxh67r9T9PtSJLFMterqqkvWEaKPY5duTiqNqZHvV	5	6	6	1548878412232
6	3NLedJK3pVRW857hL2JCUx1VBqKUz3LL7khzc6BMamTDom5tyW5c	5	3NLsqpFCaFPqjDS6vdYJo7GuywE9TMDZG7HUezhoyh34XRsGsvxV	2	2	1	1	7	jwcLxMGnhzosKjixguE7jwqE7KQXJTMgQKxcH8FVR1D3MkXuVGZ	6	7	7	1548878414000
7	3NKSGpLjfvhG68FQ3WavbEpNQNaFpe5A1sQ3ZLsLJSvTiaSfB3d4	6	3NLedJK3pVRW857hL2JCUx1VBqKUz3LL7khzc6BMamTDom5tyW5c	2	2	1	1	8	jxmFMDpSyBkbwGCK1PaaJxr71EZT3uDBTczVMbBo1XXAXvU9xvq	7	8	8	1548878416000
8	3NLURMntaMmmWpVXja4Yj3aHrB7hSm9y9sezNBENUyWjxQ2Sv979	7	3NKSGpLjfvhG68FQ3WavbEpNQNaFpe5A1sQ3ZLsLJSvTiaSfB3d4	2	2	1	1	9	jwmTRNeTX7GyySwERu6mnHUeWEJRyn3eaTsu1U6CSV1rgcSytXF	8	10	10	1548878420000
9	3NK6phZFuJuDCWqw5kD6uXNYMNSBe8eJrxs4azc4EYrB45FMqMeL	8	3NLURMntaMmmWpVXja4Yj3aHrB7hSm9y9sezNBENUyWjxQ2Sv979	2	2	1	1	10	jwieVstTyNaCfNmmRpDHqtLJQx5HWphRiGLExEN4n5H2Kg4C3Yg	9	11	11	1548878422000
10	3NKrmKsQbEt2wfaNaFk8CfPLVxD5dyhpdXFb8wpjXGww9BVgZBs8	9	3NK6phZFuJuDCWqw5kD6uXNYMNSBe8eJrxs4azc4EYrB45FMqMeL	2	2	1	1	11	jxMCYmfSomzhVw4hM2XfGXE86HmWDa8qQ2Y691PkgxviX52KpeE	10	13	13	1548878426000
11	3NKqo1PXph5BrkbyCLbZWnX23ccKNm87UxeGM1RVQ1PmnE5bdwwv	10	3NKrmKsQbEt2wfaNaFk8CfPLVxD5dyhpdXFb8wpjXGww9BVgZBs8	2	2	1	1	12	jx95ismayhhh8McwN2Vi7jP6cPQFbxNWg1XfdjcxWBBQceD9VvU	11	15	15	1548878430000
12	3NLxeVCHa7ryY663dyAUnxkjMdXS4Ux9LHWUWvMZMCApUWWx4jNu	11	3NKqo1PXph5BrkbyCLbZWnX23ccKNm87UxeGM1RVQ1PmnE5bdwwv	2	2	1	1	13	jwTpcTm6MjAXcRiKFWV97XoMTw7DoMmQghSFxNeAcrdEmZpoYzP	12	17	17	1548878434000
13	3NKChn1sPSgJjkAeEk8pVxcKKcbm5wDDiXeW3iu5ewvtaAHhjGwW	12	3NLxeVCHa7ryY663dyAUnxkjMdXS4Ux9LHWUWvMZMCApUWWx4jNu	2	2	1	1	14	jwSDCVeSpb2KLXNyX9Km3zQG17ZeGNMAQVwWvZRpuNSVCGA61JG	13	18	18	1548878436124
14	3NKpiJgG9MZeb4HqoyEWJzRHWTqHLSg8vcM3k1bm3vVMYZb5vb7z	13	3NKChn1sPSgJjkAeEk8pVxcKKcbm5wDDiXeW3iu5ewvtaAHhjGwW	2	2	1	1	15	jwL76fCD4vbbChvfLvesxZNBAN5SmQrkzvXGcDDSJLyfXX1wepc	14	20	20	1548878440000
15	3NLUvYonCtKNngtBJRRenVw6nYS5XeGBsjQC7fqvd5xEZqFYvhv3	14	3NKpiJgG9MZeb4HqoyEWJzRHWTqHLSg8vcM3k1bm3vVMYZb5vb7z	2	2	1	1	16	jw76PsczpJFUQCAD2yDzg32qTBKyBidkm58BwLEY2x6Smx73Vc6	15	22	22	1548878444000
16	3NLgjpJhWvSt8fFLgTZ7EMu1hhYNTNyqXGhAL33d3Eky7ZNfSnGf	15	3NLUvYonCtKNngtBJRRenVw6nYS5XeGBsjQC7fqvd5xEZqFYvhv3	2	2	1	1	17	jwZK74Sr8FGmC9m3GxijpJtm8ubjCFoFSTUHcbbrzfJaXnB5pbL	16	24	24	1548878448000
17	3NLK5wdveX9CqtmnnE2PXKtmJy7qBtVr9YKv8cnJx2fNuk1T49TC	16	3NLgjpJhWvSt8fFLgTZ7EMu1hhYNTNyqXGhAL33d3Eky7ZNfSnGf	2	2	1	1	18	jwUpzyj6E98j8BY9xE4sxWh3AwRfrU9bNxgN6dkqHF5v2BJ1uhG	17	25	25	1548878450000
18	3NKEL6CaHTYdkEwuBzneQDc7c9KLr6c7Z3hyZGkbQRxqqA76TzKc	17	3NLK5wdveX9CqtmnnE2PXKtmJy7qBtVr9YKv8cnJx2fNuk1T49TC	2	2	1	1	19	jxHannPaR8korqq9aEBqgTf4y3JijN45mdJiVtVAXuFimpfrk3m	18	27	27	1548878454000
19	3NKweura8oWmgoNp4XRHtz6QXzBLEnWP3prciAMsbgFWPdKCoAda	18	3NKEL6CaHTYdkEwuBzneQDc7c9KLr6c7Z3hyZGkbQRxqqA76TzKc	2	2	1	1	20	jwPBtYVqpPi6RxYsj1T6KhGf8XScZC3EKDNkxQqyXwY2wm1oUeb	19	28	28	1548878456000
20	3NLw8EmaXwjsMjKLTianZwdqCGT3HywajR8vR7to6mBJr4vZdAhw	19	3NKweura8oWmgoNp4XRHtz6QXzBLEnWP3prciAMsbgFWPdKCoAda	2	2	1	1	21	jx1zuDFGVPGkrQ6EphF6oKSvyg6HWV1vpooxwtdejBHXfFdZXxR	20	30	30	1548878460000
21	3NLV21Wh39NzLchzekcbQKd2CYy9NuiYUbveUAJicsUwHh8f238j	20	3NLw8EmaXwjsMjKLTianZwdqCGT3HywajR8vR7to6mBJr4vZdAhw	2	2	1	1	22	jxtgV9cerTkigzDeBag88fjgPaKC6vquDTBiTL7GgMeaDRZYi1g	21	31	31	1548878462000
22	3NLCoipk8wFvBZ1EHMyKzNgFEgdQY3MzoMcBd5Gh4QUqUVPz4sue	21	3NLV21Wh39NzLchzekcbQKd2CYy9NuiYUbveUAJicsUwHh8f238j	2	2	1	1	23	jwANQmmb4tqJxoUW3eYSb2EEYNj3X5T8oMQPmBVhZgHigT3ugTB	22	32	32	1548878464000
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

SELECT pg_catalog.setval('public.blocks_id_seq', 22, true);


--
-- Name: epoch_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.epoch_data_id_seq', 23, true);


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
