--
-- PostgreSQL database dump
--

\restrict WPM01GtqIKEe24zYaKQ8jt2QmiVDwMrwwXdcgcKqrtMmowzHvjzxvPpsl6juPE7

-- Dumped from database version 18.6
-- Dumped by pg_dump version 18.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: transit; Type: SCHEMA; Schema: -; Owner: transit_app
--

CREATE SCHEMA transit;


ALTER SCHEMA transit OWNER TO transit_app;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: depot; Type: TABLE; Schema: transit; Owner: transit_app
--

CREATE TABLE transit.depot (
    id bigint NOT NULL,
    name text NOT NULL,
    address text NOT NULL
);


ALTER TABLE transit.depot OWNER TO transit_app;

--
-- Name: depot_id_seq; Type: SEQUENCE; Schema: transit; Owner: transit_app
--

ALTER TABLE transit.depot ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME transit.depot_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: route; Type: TABLE; Schema: transit; Owner: transit_app
--

CREATE TABLE transit.route (
    id bigint NOT NULL,
    number text NOT NULL,
    length_km numeric(6,2) NOT NULL,
    start_date date NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE transit.route OWNER TO transit_app;

--
-- Name: route_id_seq; Type: SEQUENCE; Schema: transit; Owner: transit_app
--

ALTER TABLE transit.route ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME transit.route_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: stop; Type: TABLE; Schema: transit; Owner: transit_app
--

CREATE TABLE transit.stop (
    id bigint NOT NULL,
    name text NOT NULL,
    latitude numeric(9,6) NOT NULL,
    longitude numeric(9,6) NOT NULL
);


ALTER TABLE transit.stop OWNER TO transit_app;

--
-- Name: stop_id_seq; Type: SEQUENCE; Schema: transit; Owner: transit_app
--

ALTER TABLE transit.stop ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME transit.stop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Data for Name: depot; Type: TABLE DATA; Schema: transit; Owner: transit_app
--

COPY transit.depot (id, name, address) FROM stdin;
1	Municipal Bus Depot 1	Almaty
2	Municipal Bus Depot 2	Almaty
3	Municipal Bus Depot 3	Almaty
\.


--
-- Data for Name: route; Type: TABLE DATA; Schema: transit; Owner: transit_app
--

COPY transit.route (id, number, length_km, start_date, created_at) FROM stdin;
1	63	30.24	2020-01-01	2026-10-04 15:06:42.545017+05
2	59	24.67	2020-01-01	2026-10-04 15:06:42.545017+05
3	119	22.23	2020-01-01	2026-10-04 15:06:42.545017+05
4	79	27.56	2020-01-01	2026-10-04 15:06:42.545017+05
5	128	25.40	2020-01-01	2026-10-04 15:06:42.545017+05
\.


--
-- Data for Name: stop; Type: TABLE DATA; Schema: transit; Owner: transit_app
--

COPY transit.stop (id, name, latitude, longitude) FROM stdin;
1	KazGASA	43.207800	76.897900
2	Toraygyrov Street	43.211500	76.886900
3	Orbita-1 Microdistrict	43.205800	76.879500
4	Orbita-4 Microdistrict	43.199500	76.875000
5	First President Park	43.193600	76.886300
6	Zhandosov Street	43.226900	76.876900
7	10th Microdistrict	43.225500	76.867500
8	Altynsarin Avenue	43.229500	76.865500
9	Cooperative College	43.160500	76.875500
10	Khan Tengri Residential Complex	43.164500	76.879000
11	Almaty Sanatorium	43.178500	76.884000
12	Almaty International Airport	43.352100	77.040500
13	Academy of Civil Aviation	43.345000	77.012000
14	Central Stadium	43.238000	76.924000
15	Barlyk Market	43.218000	76.779000
\.


--
-- Name: depot_id_seq; Type: SEQUENCE SET; Schema: transit; Owner: transit_app
--

SELECT pg_catalog.setval('transit.depot_id_seq', 3, true);


--
-- Name: route_id_seq; Type: SEQUENCE SET; Schema: transit; Owner: transit_app
--

SELECT pg_catalog.setval('transit.route_id_seq', 5, true);


--
-- Name: stop_id_seq; Type: SEQUENCE SET; Schema: transit; Owner: transit_app
--

SELECT pg_catalog.setval('transit.stop_id_seq', 15, true);


--
-- Name: depot depot_pkey; Type: CONSTRAINT; Schema: transit; Owner: transit_app
--

ALTER TABLE ONLY transit.depot
    ADD CONSTRAINT depot_pkey PRIMARY KEY (id);


--
-- Name: route route_pkey; Type: CONSTRAINT; Schema: transit; Owner: transit_app
--

ALTER TABLE ONLY transit.route
    ADD CONSTRAINT route_pkey PRIMARY KEY (id);


--
-- Name: stop stop_pkey; Type: CONSTRAINT; Schema: transit; Owner: transit_app
--

ALTER TABLE ONLY transit.stop
    ADD CONSTRAINT stop_pkey PRIMARY KEY (id);


--
-- PostgreSQL database dump complete
--

\unrestrict WPM01GtqIKEe24zYaKQ8jt2QmiVDwMrwwXdcgcKqrtMmowzHvjzxvPpsl6juPE7

