--
-- PostgreSQL database dump
--

SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- Name: plpgsql; Type: PROCEDURAL LANGUAGE; Schema: -; Owner: fred
--

CREATE PROCEDURAL LANGUAGE plpgsql;


ALTER PROCEDURAL LANGUAGE plpgsql OWNER TO fred;

SET search_path = public, pg_catalog;

--
-- Name: classification_type; Type: DOMAIN; Schema: public; Owner: fred
--

CREATE DOMAIN classification_type AS integer NOT NULL
	CONSTRAINT classification_type_check CHECK ((VALUE = ANY (ARRAY[0, 1, 2, 3, 4, 5])));


ALTER DOMAIN public.classification_type OWNER TO fred;

--
-- Name: DOMAIN classification_type; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON DOMAIN classification_type IS 'allowed values of classification for registrar certification';


--
-- Name: array_filter_null(anyarray); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION array_filter_null(anyarray) RETURNS anyarray
    AS $_$
SELECT array(SELECT $1[i] FROM
    generate_series(array_lower($1,1), array_upper($1,1)) g(i) WHERE $1[i] IS NOT NULL) ;
$_$
    LANGUAGE sql IMMUTABLE STRICT;


ALTER FUNCTION public.array_filter_null(anyarray) OWNER TO fred;

--
-- Name: array_sort_dist(anyarray); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION array_sort_dist(anyarray) RETURNS anyarray
    AS $_$
SELECT COALESCE(ARRAY(
    SELECT DISTINCT $1[s.i] AS "sort"
    FROM
        generate_series(array_lower($1,1), array_upper($1,1)) AS s(i)
    ORDER BY sort
),'{}');
$_$
    LANGUAGE sql IMMUTABLE;


ALTER FUNCTION public.array_sort_dist(anyarray) OWNER TO fred;

--
-- Name: array_uniq(anyarray); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION array_uniq(anyarray) RETURNS anyarray
    AS $_$
SELECT array(SELECT DISTINCT $1[i] FROM
    generate_series(array_lower($1,1), array_upper($1,1)) g(i));
$_$
    LANGUAGE sql IMMUTABLE STRICT;


ALTER FUNCTION public.array_uniq(anyarray) OWNER TO fred;

--
-- Name: bool_to_str(boolean); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION bool_to_str(b boolean) RETURNS character
    AS $$
BEGIN
        RETURN (SELECT CASE WHEN b THEN 't' ELSE 'f' END);
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.bool_to_str(b boolean) OWNER TO fred;

--
-- Name: cancel_registrar_group_check(); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION cancel_registrar_group_check() RETURNS trigger
    AS $$
DECLARE
    registrars_in_group INTEGER;
BEGIN
    IF OLD.cancelled IS NOT NULL THEN
        RAISE EXCEPTION 'Registrar group already cancelled';
    END IF;

    IF NEW.cancelled IS NOT NULL AND EXISTS(
        SELECT *
          FROM registrar_group_map
         WHERE registrar_group_id = NEW.id
          AND registrar_group_map.member_from <= CURRENT_DATE
          AND (registrar_group_map.member_until IS NULL
                  OR (registrar_group_map.member_until >= CURRENT_DATE
                          AND  registrar_group_map.member_from
                              <> registrar_group_map.member_until)))
    THEN
        RAISE EXCEPTION 'Unable to cancel non-empty registrar group';
    END IF;

    RETURN NEW;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.cancel_registrar_group_check() OWNER TO fred;

--
-- Name: FUNCTION cancel_registrar_group_check(); Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON FUNCTION cancel_registrar_group_check() IS 'check whether registrar_group is empty and not cancelled';


--
-- Name: create_indexes_request(character varying); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION create_indexes_request(table_name character varying) RETURNS void
    AS $$
DECLARE
        create_indexes TEXT;
BEGIN
        create_indexes := 'CREATE INDEX ' || table_name || '_time_begin_idx ON ' || table_name || '(time_begin);'
                       || 'CREATE INDEX ' || table_name || '_time_end_idx ON ' || table_name || '(time_end);'
                       || 'CREATE INDEX ' || table_name || '_source_ip_idx ON ' || table_name || '(source_ip);'
                       || 'CREATE INDEX ' || table_name || '_service_idx ON ' || table_name || '(service_id);'
                       || 'CREATE INDEX ' || table_name || '_action_type_idx ON ' || table_name || '(request_type_id);'
                       || 'CREATE INDEX ' || table_name || '_monitoring_idx ON ' || table_name || '(is_monitoring);'
                       || 'CREATE INDEX ' || table_name || '_user_name_idx ON ' || table_name || '(user_name);'
                       || 'CREATE INDEX ' || table_name || '_user_id_idx ON ' || table_name || '(user_id);';
        EXECUTE create_indexes;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.create_indexes_request(table_name character varying) OWNER TO fred;

--
-- Name: create_indexes_request_data(character varying); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION create_indexes_request_data(table_name character varying) RETURNS void
    AS $$
DECLARE
        create_indexes TEXT;
BEGIN
        create_indexes = 'CREATE INDEX ' || table_name || '_entry_time_begin_idx ON ' || table_name || '(request_time_begin); CREATE INDEX ' || table_name || '_entry_id_idx ON ' || table_name || '(request_id); CREATE INDEX ' || table_name || '_is_response_idx ON ' || table_name || '(is_response);';
        EXECUTE create_indexes;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.create_indexes_request_data(table_name character varying) OWNER TO fred;

--
-- Name: create_indexes_request_object_ref(character varying); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION create_indexes_request_object_ref(table_name character varying) RETURNS void
    AS $$
DECLARE
        create_indexes TEXT;
BEGIN
        create_indexes :=
       'CREATE INDEX ' || table_name || '_id_idx ON ' || table_name || '(request_id);' ||
       'CREATE INDEX ' || table_name || '_time_begin_idx ON ' || table_name || '(request_time_begin); ' ||
       'CREATE INDEX ' || table_name || '_service_id_idx ON ' || table_name || '(request_service_id);' ||
       'CREATE INDEX ' || table_name || '_object_type_id_idx ON ' || table_name || '(object_type_id);' ||
       'CREATE INDEX ' || table_name || '_object_id_idx ON ' || table_name || '(object_id);';
        EXECUTE create_indexes;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.create_indexes_request_object_ref(table_name character varying) OWNER TO fred;

--
-- Name: create_indexes_request_property_value(character varying); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION create_indexes_request_property_value(table_name character varying) RETURNS void
    AS $$
DECLARE
        create_indexes TEXT;
BEGIN
        create_indexes = 'CREATE INDEX ' || table_name || '_entry_time_begin_idx ON ' || table_name || '(request_time_begin); CREATE INDEX ' || table_name || '_entry_id_idx ON ' || table_name || '(request_id); CREATE INDEX ' || table_name || '_name_id_idx ON ' || table_name || '(property_name_id); CREATE INDEX ' || table_name || '_value_idx ON ' || table_name || '(value); CREATE INDEX ' || table_name || '_output_idx ON ' || table_name || '(output); CREATE INDEX ' || table_name || '_parent_id_idx ON ' || table_name || '(parent_id);';
        EXECUTE create_indexes;

END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.create_indexes_request_property_value(table_name character varying) OWNER TO fred;

--
-- Name: create_indexes_session(character varying); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION create_indexes_session(table_name character varying) RETURNS void
    AS $$
DECLARE
        create_indexes TEXT;
BEGIN
        create_indexes = 'CREATE INDEX ' || table_name || '_name_idx ON ' || table_name || '(user_name); CREATE INDEX ' || table_name || '_user_id_idx ON ' || table_name || '(user_id); CREATE INDEX ' || table_name || '_login_date_idx ON ' || table_name || '(login_date);';
        EXECUTE create_indexes;

END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.create_indexes_session(table_name character varying) OWNER TO fred;

--
-- Name: create_object(integer, character varying, integer); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION create_object(crregid integer, oname character varying, otype integer) RETURNS integer
    AS $$
DECLARE iid INTEGER;
BEGIN
 iid := NEXTVAL('object_registry_id_seq');
 INSERT INTO object_registry (id,roid,name,type,crid)
 VALUES (
  iid,
  (ARRAY['C','N','D', 'K'])[otype] || LPAD(iid::text,10,'0') || '-' || (SELECT val FROM enum_parameters WHERE id = 13),
  CASE
   WHEN otype=1 THEN UPPER(oname)
   WHEN otype=2 THEN UPPER(oname)
   WHEN otype=3 THEN LOWER(oname)
   WHEN otype=4 THEN UPPER(oname)
  END,
  otype,
  crregid
 );
 RETURN iid;
 EXCEPTION
 WHEN UNIQUE_VIOLATION THEN RETURN 0;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.create_object(crregid integer, oname character varying, otype integer) OWNER TO fred;

--
-- Name: create_parts(timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION create_parts(start_date timestamp without time zone, term_date timestamp without time zone) RETURNS void
    AS $$
DECLARE
        term_month_beg TIMESTAMP WITHOUT TIME ZONE;
        cur_month_beg  TIMESTAMP WITHOUT TIME ZONE;

BEGIN
        cur_month_beg := date_trunc('month', start_date);

        term_month_beg := date_trunc('month', term_date);

        LOOP
            PERFORM create_parts_for_month(cur_month_beg);

            EXIT WHEN cur_month_beg = term_month_beg;
            cur_month_beg := cur_month_beg + interval '1 month';
        END LOOP;

END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.create_parts(start_date timestamp without time zone, term_date timestamp without time zone) OWNER TO fred;

--
-- Name: create_parts_for_month(timestamp without time zone); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION create_parts_for_month(part_time timestamp without time zone) RETURNS void
    AS $$ DECLARE
        serv INTEGER;
        cur REFCURSOR;
BEGIN

        -- a chance for minor optimization: create_tbl_* needs partitions_postfix
        --- which can be selected from table service.
        OPEN cur FOR SELECT id FROM service;
        LOOP
            FETCH cur INTO serv;
            EXIT WHEN NOT FOUND;

            PERFORM create_tbl_request(part_time, serv, false);
            PERFORM create_tbl_request_data(part_time, serv, false);
            PERFORM create_tbl_request_property_value(part_time, serv, false);
            PERFORM create_tbl_request_object_ref(part_time, serv, false);

        END LOOP;

        close cur;

        -- monitoring (service type doesn't matter here - specifying 1)
        PERFORM create_tbl_request(part_time, 1, true);
        PERFORM create_tbl_request_data(part_time, 1, true);
        PERFORM create_tbl_request_property_value(part_time, 1, true);
        PERFORM create_tbl_request_object_ref(part_time, 1, true);

        -- now service type -1 for session tables
        PERFORM create_tbl_session(part_time);

END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.create_parts_for_month(part_time timestamp without time zone) OWNER TO fred;

--
-- Name: create_tbl_request(timestamp without time zone, integer, boolean); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION create_tbl_request(time_begin timestamp without time zone, service_id integer, monitoring boolean) RETURNS void
    AS $$
DECLARE
        table_name VARCHAR(60);
        create_table    TEXT;
        spec_alter_table TEXT;
        month INTEGER;
        lower TIMESTAMP WITHOUT TIME ZONE;
        upper  TIMESTAMP WITHOUT TIME ZONE;

BEGIN
        table_name := quote_ident('request' || '_' || partition_postfix(time_begin, service_id, monitoring));

        LOCK TABLE request IN SHARE UPDATE EXCLUSIVE MODE;

        lower := to_char(date_trunc('month', time_begin), 'YYYY-MM-DD');
        upper := to_char(date_trunc('month', time_begin + interval '1 month'), 'YYYY-MM-DD');

-- CREATE table
        IF monitoring = true THEN
                -- special constraints for monitoring table
                create_table := 'CREATE TABLE ' || table_name || '    (CHECK (time_begin >= TIMESTAMP ''' || lower || ''' AND time_begin < TIMESTAMP '''
                || upper || ''' AND is_monitoring = ''' || bool_to_str(monitoring) || ''') ) INHERITS (request)';
        ELSE
                create_table := 'CREATE TABLE ' || table_name || '    (CHECK (time_begin >= TIMESTAMP ''' || lower || ''' AND time_begin < TIMESTAMP '''
                || upper || ''' AND service_id = ' || service_id || ' AND is_monitoring = ''' || bool_to_str(monitoring) || ''') ) INHERITS (request)';
        END IF;


        spec_alter_table := 'ALTER TABLE ' || table_name || ' ADD PRIMARY KEY (id); ';

        EXECUTE create_table;
        EXECUTE spec_alter_table;

        PERFORM create_indexes_request(table_name);

EXCEPTION
    WHEN duplicate_table THEN
        NULL;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.create_tbl_request(time_begin timestamp without time zone, service_id integer, monitoring boolean) OWNER TO fred;

--
-- Name: create_tbl_request_data(timestamp without time zone, integer, boolean); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION create_tbl_request_data(time_begin timestamp without time zone, service_id integer, monitoring boolean) RETURNS void
    AS $$
DECLARE
        table_name VARCHAR(60);
        table_postfix VARCHAR(40);
        create_table    TEXT;
        spec_alter_table TEXT;
        month INTEGER;
        lower TIMESTAMP WITHOUT TIME ZONE;
        upper  TIMESTAMP WITHOUT TIME ZONE;
BEGIN
        table_postfix := quote_ident(partition_postfix(time_begin, service_id, monitoring));
        table_name := 'request_data_' || table_postfix;

        LOCK TABLE request_data IN SHARE UPDATE EXCLUSIVE MODE;

        lower := to_char(date_trunc('month', time_begin), 'YYYY-MM-DD');
        upper := to_char(date_trunc('month', time_begin + interval '1 month'), 'YYYY-MM-DD');

        IF monitoring = true THEN
                create_table  =  'CREATE TABLE ' || table_name || ' (CHECK (request_time_begin >= TIMESTAMP ''' || lower || ''' AND request_time_begin < TIMESTAMP ''' || upper || ''' AND request_monitoring = ''' || bool_to_str(monitoring) || ''') ) INHERITS (request_data) ';
        ELSE
                create_table  =  'CREATE TABLE ' || table_name || ' (CHECK (request_time_begin >= TIMESTAMP ''' || lower || ''' AND request_time_begin < TIMESTAMP ''' || upper || ''' AND request_service_id = ' || service_id || ' AND request_monitoring = ''' || bool_to_str(monitoring) || ''') ) INHERITS (request_data) ';
        END IF;

        spec_alter_table = 'ALTER TABLE ' || table_name || ' ADD PRIMARY KEY (id); '
             || 'ALTER TABLE ' || table_name || ' ADD CONSTRAINT ' || table_name || '_entry_id_fkey FOREIGN KEY (request_id) REFERENCES request_' || table_postfix || '(id); ';

        EXECUTE create_table;
        EXECUTE spec_alter_table;

        PERFORM create_indexes_request_data(table_name);

EXCEPTION
    WHEN duplicate_table THEN
        NULL;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.create_tbl_request_data(time_begin timestamp without time zone, service_id integer, monitoring boolean) OWNER TO fred;

--
-- Name: create_tbl_request_object_ref(timestamp without time zone, integer, boolean); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION create_tbl_request_object_ref(time_begin timestamp without time zone, service_id integer, monitoring boolean) RETURNS void
    AS $$
DECLARE
        table_name VARCHAR(60);
        table_postfix VARCHAR (40);
        create_table    TEXT;
        spec_alter_table TEXT;
        month INTEGER;
        lower TIMESTAMP WITHOUT TIME ZONE;
        upper  TIMESTAMP WITHOUT TIME ZONE;
BEGIN
        table_postfix := quote_ident(partition_postfix(time_begin, service_id, monitoring));
        table_name := 'request_object_ref_' || table_postfix;

        LOCK TABLE request_property_value IN SHARE UPDATE EXCLUSIVE MODE;

        lower := to_char(date_trunc('month', time_begin), 'YYYY-MM-DD');
        upper := to_char(date_trunc('month', time_begin + interval '1 month'), 'YYYY-MM-DD');

        IF monitoring = true THEN
                create_table  =  'CREATE TABLE ' || table_name || ' (CHECK (request_time_begin >= TIMESTAMP ''' || lower || ''' AND request_time_begin < TIMESTAMP ''' || upper || '''  AND request_monitoring = ''' || bool_to_str(monitoring) || ''') ) INHERITS (request_object_ref) ';
        ELSE
                create_table  =  'CREATE TABLE ' || table_name || ' (CHECK (request_time_begin >= TIMESTAMP ''' || lower || ''' AND request_time_begin < TIMESTAMP ''' || upper || '''  AND request_service_id = ' || service_id || ' AND request_monitoring = ''' || bool_to_str(monitoring) || ''') ) INHERITS (request_object_ref) ';
        END IF;

        spec_alter_table = 'ALTER TABLE ' || table_name || ' ADD PRIMARY KEY (id); ALTER TABLE ' || table_name || ' ADD CONSTRAINT ' || table_name || '_entry_id_fkey FOREIGN KEY (request_id) REFERENCES request_' || table_postfix || '(id); ALTER TABLE ' || table_name || ' ADD CONSTRAINT ' || table_name || '_object_type_id_fkey FOREIGN KEY (object_type_id) REFERENCES request_object_type(id); ';

        EXECUTE create_table;
        EXECUTE spec_alter_table;
        PERFORM create_indexes_request_object_ref(table_name);
EXCEPTION
    WHEN duplicate_table THEN
        NULL;

END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.create_tbl_request_object_ref(time_begin timestamp without time zone, service_id integer, monitoring boolean) OWNER TO fred;

--
-- Name: create_tbl_request_property_value(timestamp without time zone, integer, boolean); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION create_tbl_request_property_value(time_begin timestamp without time zone, service_id integer, monitoring boolean) RETURNS void
    AS $$
DECLARE
        table_name VARCHAR(60);
        table_postfix VARCHAR (40);
        create_table    TEXT;
        spec_alter_table TEXT;
        month INTEGER;
        lower TIMESTAMP WITHOUT TIME ZONE;
        upper  TIMESTAMP WITHOUT TIME ZONE;
BEGIN
        table_postfix := quote_ident(partition_postfix(time_begin, service_id, monitoring));
        table_name := 'request_property_value_' || table_postfix;

        LOCK TABLE request_property_value IN SHARE UPDATE EXCLUSIVE MODE;

        lower := to_char(date_trunc('month', time_begin), 'YYYY-MM-DD');
        upper := to_char(date_trunc('month', time_begin + interval '1 month'), 'YYYY-MM-DD');

        IF monitoring = true THEN
                create_table  =  'CREATE TABLE ' || table_name || ' (CHECK (request_time_begin >= TIMESTAMP ''' || lower || ''' AND request_time_begin < TIMESTAMP ''' || upper || '''  AND request_monitoring = ''' || bool_to_str(monitoring) || ''') ) INHERITS (request_property_value) ';
        ELSE
                create_table  =  'CREATE TABLE ' || table_name || ' (CHECK (request_time_begin >= TIMESTAMP ''' || lower || ''' AND request_time_begin < TIMESTAMP ''' || upper || '''  AND request_service_id = ' || service_id || ' AND request_monitoring = ''' || bool_to_str(monitoring) || ''') ) INHERITS (request_property_value) ';
        END IF;

        spec_alter_table = 'ALTER TABLE ' || table_name || ' ADD PRIMARY KEY (id); ALTER TABLE ' || table_name || ' ADD CONSTRAINT ' || table_name || '_entry_id_fkey FOREIGN KEY (request_id) REFERENCES request_' || table_postfix || '(id); ALTER TABLE ' || table_name || ' ADD CONSTRAINT ' || table_name || '_name_id_fkey FOREIGN KEY (property_name_id) REFERENCES request_property_name(id); ALTER TABLE ' || table_name || ' ADD CONSTRAINT ' || table_name || '_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES ' || table_name || '(id); ';

        EXECUTE create_table;
        EXECUTE spec_alter_table;
        PERFORM create_indexes_request_property_value(table_name);
EXCEPTION
    WHEN duplicate_table THEN
        NULL;

END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.create_tbl_request_property_value(time_begin timestamp without time zone, service_id integer, monitoring boolean) OWNER TO fred;

--
-- Name: create_tbl_session(timestamp without time zone); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION create_tbl_session(time_begin timestamp without time zone) RETURNS void
    AS $$
DECLARE
        table_name VARCHAR(60);
        create_table    TEXT;
        spec_alter_table TEXT;
        month INTEGER;
        lower TIMESTAMP WITHOUT TIME ZONE;
        upper  TIMESTAMP WITHOUT TIME ZONE;

BEGIN
        table_name := quote_ident('session_' || partition_postfix(time_begin, -1, false));

        LOCK TABLE session IN SHARE UPDATE EXCLUSIVE MODE;

        lower := to_char(date_trunc('month', time_begin), 'YYYY-MM-DD');
        upper := to_char(date_trunc('month', time_begin + interval '1 month'), 'YYYY-MM-DD');

        create_table =  'CREATE TABLE ' || table_name || '    (CHECK (login_date >= TIMESTAMP ''' || lower || ''' AND login_date < TIMESTAMP ''' || upper || ''') ) INHERITS (session) ';

        spec_alter_table = 'ALTER TABLE ' || table_name || ' ADD PRIMARY KEY (id); ';


        EXECUTE create_table;
        EXECUTE spec_alter_table;

        PERFORM create_indexes_session(table_name);

EXCEPTION
    WHEN duplicate_table THEN
        NULL;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.create_tbl_session(time_begin timestamp without time zone) OWNER TO fred;

--
-- Name: create_tmp_table(character varying); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION create_tmp_table(tname character varying) RETURNS void
    AS $$
BEGIN
 EXECUTE 'CREATE TEMPORARY TABLE ' || tname || ' (id BIGINT PRIMARY KEY)';
 EXCEPTION
 WHEN DUPLICATE_TABLE THEN EXECUTE 'TRUNCATE TABLE ' || tname;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.create_tmp_table(tname character varying) OWNER TO fred;

--
-- Name: date_month_test(date, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION date_month_test(date, character varying, character varying, character varying) RETURNS boolean
    AS $_$
SELECT $1 + ($2||' month')::interval + ($3||' hours')::interval
       <= CURRENT_TIMESTAMP AT TIME ZONE $4;
$_$
    LANGUAGE sql IMMUTABLE;


ALTER FUNCTION public.date_month_test(date, character varying, character varying, character varying) OWNER TO fred;

--
-- Name: date_test(date, character varying); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION date_test(date, character varying) RETURNS boolean
    AS $_$
SELECT $1 + ($2||' days')::interval <= CURRENT_DATE ;
$_$
    LANGUAGE sql IMMUTABLE;


ALTER FUNCTION public.date_test(date, character varying) OWNER TO fred;

--
-- Name: date_time_test(date, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION date_time_test(date, character varying, character varying, character varying) RETURNS boolean
    AS $_$
SELECT $1 + ($2||' days')::interval + ($3||' hours')::interval
       <= CURRENT_TIMESTAMP AT TIME ZONE $4;
$_$
    LANGUAGE sql IMMUTABLE;


ALTER FUNCTION public.date_time_test(date, character varying, character varying, character varying) OWNER TO fred;

--
-- Name: get_result_code_id(integer, integer); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION get_result_code_id(integer, integer) RETURNS integer
    AS $_$
DECLARE
    result_code_id INTEGER;
BEGIN

    SELECT id FROM result_code INTO result_code_id
        WHERE service_id=$1 and result_code=$2 ;

    IF result_code_id is null THEN
        RAISE WARNING 'result_code.id not found for service_id=% and result_code=% ', $1, $2;
    END IF;
    RETURN result_code_id;
END;
$_$
    LANGUAGE plpgsql;


ALTER FUNCTION public.get_result_code_id(integer, integer) OWNER TO fred;

--
-- Name: get_state_descriptions(bigint, character varying); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION get_state_descriptions(object_id bigint, lang_code character varying) RETURNS text
    AS $_$
SELECT array_to_string(ARRAY((
    SELECT
        array_to_string(ARRAY[eos.external::char,
        COALESCE(eos.importance::varchar, ''),
        eos.name,
        COALESCE(osd.description, '')], E'#')
    FROM object_state os
    LEFT JOIN enum_object_states eos ON eos.id = os.state_id
    LEFT JOIN enum_object_states_desc osd ON osd.state_id = eos.id AND lang = $2
    WHERE os.object_id = $1
        AND os.valid_from <= CURRENT_TIMESTAMP
        AND (os.valid_to IS NULL OR os.valid_to > CURRENT_TIMESTAMP)
    ORDER BY eos.importance
)), E'&')
$_$
    LANGUAGE sql;


ALTER FUNCTION public.get_state_descriptions(object_id bigint, lang_code character varying) OWNER TO fred;

-- For PostgreSQL versions < 8.4
CREATE AGGREGATE array_agg(anyelement) (
    SFUNC=array_append,
    STYPE=anyarray,
    INITCOND='{}'
);

--
-- Name: lock_object_state_request(); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION lock_object_state_request() RETURNS trigger
    AS $$
DECLARE
max_id_to_delete BIGINT;
BEGIN
  --lock for manual states
  PERFORM * FROM enum_object_states WHERE id = NEW.state_id AND manual = true;
  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  RAISE NOTICE 'lock_object_state_request NEW.id: % NEW.state_id: % NEW.object_id: %'
  , NEW.id, NEW.state_id, NEW.object_id ;
    PERFORM lock_object_state_request_lock( NEW.state_id, NEW.object_id);
  --try cleanup
  BEGIN
    SELECT MAX(id) - 100 FROM object_state_request_lock INTO max_id_to_delete;
    PERFORM * FROM object_state_request_lock
      WHERE id < max_id_to_delete FOR UPDATE NOWAIT;
    IF FOUND THEN
      DELETE FROM object_state_request_lock
        WHERE id < max_id_to_delete;
    END IF;
  EXCEPTION WHEN lock_not_available THEN
    RAISE NOTICE 'cleanup lock not available';
  END;

  RETURN NEW;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.lock_object_state_request() OWNER TO fred;

--
-- Name: FUNCTION lock_object_state_request(); Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON FUNCTION lock_object_state_request() IS 'lock changes of object state requests by object and state';


--
-- Name: lock_object_state_request_lock(bigint, bigint); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION lock_object_state_request_lock(f_state_id bigint, f_object_id bigint) RETURNS void
    AS $$
DECLARE
BEGIN
    PERFORM * FROM object_state_request_lock
    WHERE state_id = f_state_id
    AND object_id = f_object_id ORDER BY id FOR UPDATE; --wait if locked
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Failed to lock state_id: % object_id: %', f_state_id, f_object_id;
    END IF;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.lock_object_state_request_lock(f_state_id bigint, f_object_id bigint) OWNER TO fred;

--
-- Name: lock_public_request(); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION lock_public_request() RETURNS trigger
    AS $$
DECLARE
  nobject RECORD;
  max_id_to_delete BIGINT;
BEGIN
  RAISE NOTICE 'lock_public_request start NEW.id: % NEW.request_type: %'
  , NEW.id, NEW.request_type;

  FOR nobject IN SELECT prom.object_id
    FROM public_request_objects_map prom
    JOIN object_registry obr ON obr.id = prom.object_id
    WHERE prom.request_id = NEW.id
  LOOP
    RAISE NOTICE 'lock_public_request nobject.object_id: %'
    , nobject.object_id;
    PERFORM lock_public_request_lock( NEW.request_type, nobject.object_id);
  END LOOP;

  --try cleanup
  BEGIN
    SELECT MAX(id) - 100 FROM public_request_lock INTO max_id_to_delete;
    PERFORM * FROM public_request_lock
      WHERE id < max_id_to_delete FOR UPDATE NOWAIT;
    IF FOUND THEN
      DELETE FROM public_request_lock
        WHERE id < max_id_to_delete;
    END IF;
  EXCEPTION WHEN lock_not_available THEN
    RAISE NOTICE 'cleanup lock not available';
  END;

  RETURN NEW;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.lock_public_request() OWNER TO fred;

--
-- Name: FUNCTION lock_public_request(); Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON FUNCTION lock_public_request() IS 'lock changes of public requests by object and request type';


--
-- Name: lock_public_request_lock(bigint, bigint); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION lock_public_request_lock(f_request_type_id bigint, f_object_id bigint) RETURNS void
    AS $$
DECLARE
BEGIN
    PERFORM * FROM public_request_lock
    WHERE request_type = f_request_type_id
    AND object_id = f_object_id ORDER BY id FOR UPDATE; --wait if locked
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Failed to lock request_type_id: % object_id: %', f_request_type_id, f_object_id;
    END IF;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.lock_public_request_lock(f_request_type_id bigint, f_object_id bigint) OWNER TO fred;

--
-- Name: object_history_insert(); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION object_history_insert() RETURNS trigger
    AS $$
  BEGIN
    UPDATE object_state SET ohid_from=NEW.historyid
    WHERE ohid_from ISNULL AND object_id=NEW.id;
    RETURN NEW;
  END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.object_history_insert() OWNER TO fred;

--
-- Name: object_registry_update_history_rec(); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION object_registry_update_history_rec() RETURNS trigger
    AS $$
BEGIN
    -- when updation object, set valid_to and next of previous history record
    IF OLD.historyid != NEW.historyid THEN
        UPDATE history
            SET valid_to = NOW(), -- NOW() is the same during the transaction, so this will be the same as valid_from of new history record
                next = NEW.historyid
            WHERE id = OLD.historyid;
    END IF;

    -- when deleting object (setting object_registry.erdate), set valid_to of current history record
    IF OLD.erdate IS NULL and NEW.erdate IS NOT NULL THEN
        UPDATE history
            SET valid_to = NEW.erdate
            WHERE id = OLD.historyid;
    END IF;

    RETURN NEW;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.object_registry_update_history_rec() OWNER TO fred;

--
-- Name: partition_postfix(timestamp without time zone, integer, boolean); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION partition_postfix(rec_time timestamp without time zone, serv integer, is_monitoring boolean) RETURNS character varying
    AS $$
DECLARE
        date_part VARCHAR(5);
        service_postfix VARCHAR(10);
BEGIN
        date_part := to_char(date_trunc('month', rec_time), 'YY_MM');

        IF (serv = -1) THEN
                RETURN date_part;
        elsif (is_monitoring) THEN
                RETURN 'mon_' || date_part;
        ELSE
                SELECT partition_postfix into service_postfix from service where id = serv;
                RETURN service_postfix || date_part;
        END IF;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.partition_postfix(rec_time timestamp without time zone, serv integer, is_monitoring boolean) OWNER TO fred;

--
-- Name: registrar_certification_life_check(); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION registrar_certification_life_check() RETURNS trigger
    AS $$
DECLARE
    last_reg_cert RECORD;
BEGIN
    IF NEW.valid_from > NEW.valid_until THEN
        RAISE EXCEPTION 'Invalid registrar certification life: valid_from > valid_until';
    END IF;

    IF TG_OP = 'INSERT' THEN
        SELECT * FROM registrar_certification INTO last_reg_cert
            WHERE registrar_id = NEW.registrar_id AND id < NEW.id
            ORDER BY valid_from DESC, id DESC LIMIT 1;
        IF FOUND THEN
            IF last_reg_cert.valid_until > NEW.valid_from  THEN
                RAISE EXCEPTION 'Invalid registrar certification life: last valid_until > new valid_from';
            END IF;
        END IF;
    ELSEIF TG_OP = 'UPDATE' THEN
        IF NEW.valid_from <> OLD.valid_from THEN
            RAISE EXCEPTION 'Change of valid_from not allowed';
        END IF;
        IF NEW.valid_until > OLD.valid_until THEN
            RAISE EXCEPTION 'Certification prolongation not allowed';
        END IF;
        IF NEW.registrar_id <> OLD.registrar_id THEN
            RAISE EXCEPTION 'Change of registrar not allowed';
        END IF;
    END IF;

    RETURN NEW;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.registrar_certification_life_check() OWNER TO fred;

--
-- Name: FUNCTION registrar_certification_life_check(); Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON FUNCTION registrar_certification_life_check() IS 'check whether registrar_certification life is valid';


--
-- Name: registrar_credit_change_lock(); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION registrar_credit_change_lock() RETURNS trigger
    AS $$
DECLARE
    registrar_credit_result RECORD;
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT id, credit FROM registrar_credit INTO registrar_credit_result
            WHERE id = NEW.registrar_credit_id FOR UPDATE;
        IF FOUND THEN
            UPDATE registrar_credit
                SET credit = credit + NEW.balance_change
                WHERE id = registrar_credit_result.id;
        ELSE
            RAISE EXCEPTION 'Invalid registrar_credit_id';
        END IF;
    ELSE
        RAISE EXCEPTION 'Unallowed operation to registrar_credit_transaction';
    END IF;
    RETURN NEW;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.registrar_credit_change_lock() OWNER TO fred;

--
-- Name: FUNCTION registrar_credit_change_lock(); Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON FUNCTION registrar_credit_change_lock() IS 'check and lock insert into registrar_credit_transaction disable update and delete';


--
-- Name: registrar_group_map_check(); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION registrar_group_map_check() RETURNS trigger
    AS $$
DECLARE
    last_reg_map RECORD;
BEGIN
    IF NEW.member_until IS NOT NULL AND NEW.member_from > NEW.member_until THEN
        RAISE EXCEPTION 'Invalid registrar membership life: member_from > member_until';
    END IF;

    IF TG_OP = 'INSERT' THEN
        SELECT * INTO last_reg_map
           FROM registrar_group_map
          WHERE registrar_id = NEW.registrar_id
            AND registrar_group_id = NEW.registrar_group_id
            AND id < NEW.id
          ORDER BY member_from DESC, id DESC
          LIMIT 1;
        IF FOUND THEN
            IF last_reg_map.member_until IS NULL THEN
                UPDATE registrar_group_map
                   SET member_until = NEW.member_from
                  WHERE id = last_reg_map.id;
                last_reg_map.member_until := NEW.member_from;
            END IF;
            IF last_reg_map.member_until > NEW.member_from  THEN
                RAISE EXCEPTION 'Invalid registrar membership life: last member_until > new member_from';
            END IF;
        END IF;

    ELSEIF TG_OP = 'UPDATE' THEN
        IF NEW.member_from <> OLD.member_from THEN
            RAISE EXCEPTION 'Change of member_from not allowed';
        END IF;

        IF NEW.member_until IS NULL AND OLD.member_until IS NOT NULL THEN
            RAISE EXCEPTION 'Change of member_until not allowed';
        END IF;

        IF NEW.member_until IS NOT NULL AND OLD.member_until IS NOT NULL
            AND NEW.member_until <> OLD.member_until THEN
            RAISE EXCEPTION 'Change of member_until not allowed';
        END IF;

        IF NEW.registrar_group_id <> OLD.registrar_group_id THEN
            RAISE EXCEPTION 'Change of registrar_group not allowed';
        END IF;

        IF NEW.registrar_id <> OLD.registrar_id THEN
            RAISE EXCEPTION 'Change of registrar not allowed';
        END IF;
    END IF;

    RETURN NEW;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.registrar_group_map_check() OWNER TO fred;

--
-- Name: FUNCTION registrar_group_map_check(); Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON FUNCTION registrar_group_map_check() IS 'check whether registrar membership change is valid';


--
-- Name: status_clear_lock(integer, integer); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION status_clear_lock(integer, integer) RETURNS boolean
    AS $_$
SELECT id IS NOT NULL FROM object_state
WHERE object_id=$1 AND state_id=$2 AND valid_to IS NULL FOR UPDATE;
$_$
    LANGUAGE sql;


ALTER FUNCTION public.status_clear_lock(integer, integer) OWNER TO fred;

--
-- Name: status_clear_state(boolean, integer, integer); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION status_clear_state(_cond boolean, _state_id integer, _object_id integer) RETURNS void
    AS $$
 BEGIN
   IF NOT _cond THEN
     -- condition (valid_to IS NULL) is essential to avoid closing closed
     -- state
     UPDATE object_state SET valid_to = CURRENT_TIMESTAMP
     WHERE state_id = _state_id AND valid_to IS NULL
     AND object_id = _object_id;
   END IF;
 END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.status_clear_state(_cond boolean, _state_id integer, _object_id integer) OWNER TO fred;

--
-- Name: status_set_state(boolean, integer, integer); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION status_set_state(_cond boolean, _state_id integer, _object_id integer) RETURNS void
    AS $$
 BEGIN
   IF _cond THEN
     -- optimistic access, don't check if status exists
     -- but may fail on UNIQUE constraint, so catching exception
     INSERT INTO object_state (object_id, state_id, valid_from)
     VALUES (_object_id, _state_id, CURRENT_TIMESTAMP);
   END IF;
 EXCEPTION
   WHEN UNIQUE_VIOLATION THEN
   -- do nothing
 END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.status_set_state(_cond boolean, _state_id integer, _object_id integer) OWNER TO fred;

--
-- Name: status_update_contact_map(); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION status_update_contact_map() RETURNS trigger
    AS $$
  DECLARE
    _num INTEGER;
    _contact_old INTEGER;
    _contact_new INTEGER;
  BEGIN
    _contact_old := NULL;
    _contact_new := NULL;
    -- is it INSERT operation
    IF TG_OP = 'INSERT' THEN
      _contact_new := NEW.contactid;
    -- is it UPDATE operation
    ELSIF TG_OP = 'UPDATE' THEN
      IF NEW.contactid <> OLD.contactid THEN
        _contact_old := OLD.contactid;
        _contact_new := NEW.contactid;
      END IF;
    -- is it DELETE operation
    ELSIF TG_OP = 'DELETE' THEN
      _contact_old := OLD.contactid;
    END IF;

    -- add contact's linked status if there is none
    EXECUTE status_set_state(
      _contact_new IS NOT NULL, 16, _contact_new
    );
    -- remove contact's linked status if not bound
    -- locking must be done (see comment above)
    IF _contact_old IS NOT NULL AND
       status_clear_lock(_contact_old, 16) IS NOT NULL
    THEN
      SELECT count(*) INTO _num FROM domain WHERE registrant = OLD.contactid;
      IF _num = 0 THEN
        SELECT count(*) INTO _num FROM domain_contact_map
            WHERE contactid = OLD.contactid;
        IF _num = 0 THEN
          SELECT count(*) INTO _num FROM nsset_contact_map
              WHERE contactid = OLD.contactid;
          IF _num = 0 THEN
            SELECT count(*) INTO _num FROM keyset_contact_map
                WHERE contactid = OLD.contactid;
            EXECUTE status_clear_state(_num <> 0, 16, OLD.contactid);
          END IF;
        END IF;
      END IF;
    END IF;
    RETURN NULL;
  END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.status_update_contact_map() OWNER TO fred;

--
-- Name: status_update_domain(); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION status_update_domain() RETURNS trigger
    AS $$
  DECLARE
    _num INTEGER;
    _nsset_old INTEGER;
    _registrant_old INTEGER;
    _keyset_old INTEGER;
    _nsset_new INTEGER;
    _registrant_new INTEGER;
    _keyset_new INTEGER;
    _ex_not VARCHAR;
    _ex_dns VARCHAR;
    _ex_let VARCHAR;
--    _ex_reg VARCHAR;
    _proc_tm VARCHAR;
    _proc_tz VARCHAR;
    _proc_tm2 VARCHAR;
  BEGIN
    _nsset_old := NULL;
    _registrant_old := NULL;
    _keyset_old := NULL;
    _nsset_new := NULL;
    _registrant_new := NULL;
    _keyset_new := NULL;
    SELECT val INTO _ex_not FROM enum_parameters WHERE id=3;
    SELECT val INTO _ex_dns FROM enum_parameters WHERE id=4;
    SELECT val INTO _ex_let FROM enum_parameters WHERE id=5;
--    SELECT val INTO _ex_reg FROM enum_parameters WHERE id=6;
    SELECT val INTO _proc_tm FROM enum_parameters WHERE id=9;
    SELECT val INTO _proc_tz FROM enum_parameters WHERE id=10;
    SELECT val INTO _proc_tm2 FROM enum_parameters WHERE id=14;
    -- is it INSERT operation
    IF TG_OP = 'INSERT' THEN
      _registrant_new := NEW.registrant;
      _nsset_new := NEW.nsset;
      _keyset_new := NEW.keyset;
      -- we ignore exdate, for new domain it shouldn't influence its state
      -- state: nsset missing
      EXECUTE status_update_state(
        NEW.nsset ISNULL, 14, NEW.id
      );
    -- is it UPDATE operation
    ELSIF TG_OP = 'UPDATE' THEN
      IF NEW.registrant <> OLD.registrant THEN
        _registrant_old := OLD.registrant;
        _registrant_new := NEW.registrant;
      END IF;
      IF COALESCE(NEW.nsset,0) <> COALESCE(OLD.nsset,0) THEN
        _nsset_old := OLD.nsset;
        _nsset_new := NEW.nsset;
      END IF;
      IF COALESCE(NEW.keyset,0) <> COALESCE(OLD.keyset,0) THEN
        _keyset_old := OLD.keyset;
        _keyset_new := NEW.keyset;
      END IF;
      -- take care of all domain statuses
      IF NEW.exdate <> OLD.exdate THEN
        -- at the first sight it seems that there should be checking
        -- for renewProhibited state before setting all of these states
        -- as it's done in global (1. type) views
        -- but the point is that when renewProhibited is set
        -- there is no way to change exdate so this situation can never happen
        -- state: expiration warning
        EXECUTE status_update_state(
          date_test(NEW.exdate::date,_ex_not),
          8, NEW.id
        );
        -- state: expired
        EXECUTE status_update_state(
          date_test(NEW.exdate::date,'0'),
          9, NEW.id
        );
        -- state: unguarded
        EXECUTE status_update_state(
          date_time_test(NEW.exdate::date,_ex_dns,_proc_tm2,_proc_tz),
          10, NEW.id
        );
        -- state: deleteWarning
        EXECUTE status_update_state(
          date_test(NEW.exdate::date,_ex_let),
          19, NEW.id
        );
        -- state: delete candidate (seems useless - cannot switch after del)
        -- for now delete state will be set only globaly
--        EXECUTE status_update_state(
--          date_time_test(NEW.exdate::date,_ex_reg,_proc_tm,_proc_tz),
--          17, NEW.id
--        );
      END IF; -- change in exdate
      IF COALESCE(NEW.nsset,0) <> COALESCE(OLD.nsset,0) THEN
        -- state: nsset missing
        EXECUTE status_update_state(
          NEW.nsset ISNULL, 14, NEW.id
        );
      END IF; -- change in nsset
    -- is it DELETE operation
    ELSIF TG_OP = 'DELETE' THEN
      _registrant_old := OLD.registrant;
      _nsset_old := OLD.nsset; -- may be NULL!
      _keyset_old := OLD.keyset; -- may be NULL!
      -- exdate is meaningless when deleting (probably)
    END IF;

    -- add registrant's linked status if there is none
    EXECUTE status_set_state(
      _registrant_new IS NOT NULL, 16, _registrant_new
    );
    -- add nsset's linked status if there is none
    EXECUTE status_set_state(
      _nsset_new IS NOT NULL, 16, _nsset_new
    );
    -- add keyset's linked status if there is none
    EXECUTE status_set_state(
      _keyset_new IS NOT NULL, 16, _keyset_new
    );
    -- remove registrant's linked status if not bound
    -- locking must be done (see comment above)
    IF _registrant_old IS NOT NULL AND
       status_clear_lock(_registrant_old, 16) IS NOT NULL
    THEN
      SELECT count(*) INTO _num FROM domain
          WHERE registrant = OLD.registrant;
      IF _num = 0 THEN
        SELECT count(*) INTO _num FROM domain_contact_map
            WHERE contactid = OLD.registrant;
        IF _num = 0 THEN
          SELECT count(*) INTO _num FROM nsset_contact_map
              WHERE contactid = OLD.registrant;
          IF _num = 0 THEN
            SELECT count(*) INTO _num FROM keyset_contact_map
                WHERE contactid = OLD.registrant;
            EXECUTE status_clear_state(_num <> 0, 16, OLD.registrant);
          END IF;
        END IF;
      END IF;
    END IF;
    -- remove nsset's linked status if not bound
    -- locking must be done (see comment above)
    IF _nsset_old IS NOT NULL AND
       status_clear_lock(_nsset_old, 16) IS NOT NULL
    THEN
      SELECT count(*) INTO _num FROM domain WHERE nsset = OLD.nsset;
      EXECUTE status_clear_state(_num <> 0, 16, OLD.nsset);
    END IF;
    -- remove keyset's linked status if not bound
    -- locking must be done (see comment above)
    IF _keyset_old IS NOT NULL AND
       status_clear_lock(_keyset_old, 16) IS NOT NULL
    THEN
      SELECT count(*) INTO _num FROM domain WHERE keyset = OLD.keyset;
      EXECUTE status_clear_state(_num <> 0, 16, OLD.keyset);
    END IF;
    RETURN NULL;
  END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.status_update_domain() OWNER TO fred;

--
-- Name: status_update_enumval(); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION status_update_enumval() RETURNS trigger
    AS $$
  DECLARE
    _num INTEGER;
  BEGIN
    -- is it UPDATE operation
    IF TG_OP = 'UPDATE' AND NEW.exdate <> OLD.exdate THEN
      -- state: validation warning 1
      EXECUTE status_update_state(
        NEW.exdate::date - INTERVAL '30 days' <= CURRENT_DATE, 11, NEW.domainid
      );
      -- state: validation warning 2
      EXECUTE status_update_state(
        NEW.exdate::date - INTERVAL '15 days' <= CURRENT_DATE, 12, NEW.domainid
      );
      -- state: not validated
      EXECUTE status_update_state(
        NEW.exdate::date + INTERVAL '14 hours' <= CURRENT_TIMESTAMP, 13, NEW.domainid
      );
    END IF;
    RETURN NULL;
  END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.status_update_enumval() OWNER TO fred;

--
-- Name: status_update_hid(); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION status_update_hid() RETURNS trigger
    AS $$
  BEGIN
    IF TG_OP = 'UPDATE' AND NEW.ohid_to ISNULL THEN
      SELECT historyid INTO NEW.ohid_to
      FROM object_registry WHERE id=NEW.object_id;
    ELSE IF TG_OP = 'INSERT' AND NEW.ohid_from ISNULL THEN
        SELECT historyid INTO NEW.ohid_from
        FROM object_registry WHERE id=NEW.object_id;
      END IF;
    END IF;
    RETURN NEW;
  END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.status_update_hid() OWNER TO fred;

--
-- Name: status_update_object_state(); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION status_update_object_state() RETURNS trigger
    AS $$
  DECLARE
    _states INTEGER[];
  BEGIN
    IF NEW.state_id = ANY (ARRAY[5,6,10,13,14]) THEN
      -- activation is only done on states that are relevant for
      -- dependant states to stop RECURSION
      SELECT array_accum(state_id) INTO _states FROM object_state
          WHERE valid_to IS NULL AND object_id = NEW.object_id;
      -- set or clear status 15 (outzone)
      EXECUTE status_update_state(
        (14 = ANY (_states)) OR -- nsset is null
        (5  = ANY (_states)) OR -- serverOutzoneManual
        (NOT (6 = ANY (_states)) AND -- not serverInzoneManual
          ((10 = ANY (_states)) OR -- unguarded
           (13 = ANY (_states)))),  -- not validated
        15, NEW.object_id -- => set outzone
      );
      -- set or clear status 15 (outzoneUnguarded)
      EXECUTE status_update_state(
        NOT (6 = ANY (_states)) AND -- not serverInzoneManual
            (10 = ANY (_states)), -- unguarded
        20, NEW.object_id -- => set ouzoneUnguarded
      );
    END IF;
    RETURN NEW;
  END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.status_update_object_state() OWNER TO fred;

--
-- Name: status_update_state(boolean, integer, integer); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION status_update_state(_cond boolean, _state_id integer, _object_id integer) RETURNS void
    AS $$
 DECLARE
   _num INTEGER;
 BEGIN
   -- don't know if it's faster to not test condition twise or call EXECUTE
   -- that immidietely return (removing IF), guess is twice test is faster
   IF _cond THEN
     EXECUTE status_set_state(_cond, _state_id, _object_id);
   ELSE
     EXECUTE status_clear_state(_cond, _state_id, _object_id);
   END IF;
 END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.status_update_state(_cond boolean, _state_id integer, _object_id integer) OWNER TO fred;

--
-- Name: tr_request(bigint, timestamp without time zone, timestamp without time zone, inet, integer, integer, bigint, character varying, integer, boolean); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION tr_request(id bigint, time_begin timestamp without time zone, time_end timestamp without time zone, source_ip inet, service_id integer, request_type_id integer, session_id bigint, user_name character varying, user_id integer, is_monitoring boolean) RETURNS void
    AS $$
DECLARE
        table_name VARCHAR(50);
        stmt       TEXT;
BEGIN
        table_name = quote_ident('request_' || partition_postfix(time_begin, service_id, is_monitoring));

        stmt := 'INSERT INTO ' || table_name || ' (id, time_begin, time_end, source_ip, service_id, request_type_id, session_id, user_name, user_id, is_monitoring) VALUES ('
                || COALESCE(id::TEXT, 'NULL')           || ', '
                || COALESCE(quote_literal(time_begin), 'NULL')           || ', '
                || COALESCE(quote_literal(time_end), 'NULL')             || ', '
                || COALESCE(quote_literal(host(source_ip)), 'NULL')      || ', '
                || COALESCE(service_id::TEXT, 'NULL')      || ', '
                || COALESCE(request_type_id::TEXT, 'NULL')  || ', '
                || COALESCE(session_id::TEXT, 'NULL')   || ', '
                || COALESCE(quote_literal(user_name), 'NULL')            || ', '
                || COALESCE(user_id::TEXT, 'NULL')                       || ', '
                || '''' || bool_to_str(is_monitoring)   || ''') ';

        -- raise notice 'request Generated insert: %', stmt;
        EXECUTE stmt;

EXCEPTION
        WHEN undefined_table THEN
        BEGIN
                PERFORM create_tbl_request(time_begin, service_id, is_monitoring);

                EXECUTE stmt;
        END;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.tr_request(id bigint, time_begin timestamp without time zone, time_end timestamp without time zone, source_ip inet, service_id integer, request_type_id integer, session_id bigint, user_name character varying, user_id integer, is_monitoring boolean) OWNER TO fred;

--
-- Name: tr_request_data(timestamp without time zone, integer, boolean, bigint, text, boolean); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION tr_request_data(request_time_begin timestamp without time zone, request_service_id integer, request_monitoring boolean, request_id bigint, content text, is_response boolean) RETURNS void
    AS $$
DECLARE
        table_name VARCHAR(50);
        stmt  TEXT;
BEGIN
        table_name := quote_ident('request_data_' || partition_postfix(request_time_begin, request_service_id, request_monitoring));
        stmt := 'INSERT INTO ' || table_name || '(request_time_begin, request_service_id, request_monitoring, request_id,  content, is_response) VALUES ('
            || COALESCE(quote_literal(request_time_begin), 'NULL')                 || ', '
            || COALESCE(request_service_id::TEXT, 'NULL')            || ', '
            || '''' || bool_to_str(request_monitoring)            || ''', '
            || COALESCE(request_id::TEXT, 'NULL')                 || ', '
            || COALESCE(quote_literal(content), 'NULL')                          || ', '
            || COALESCE('''' || bool_to_str(is_response) || '''' , 'NULL') || ') ';

        -- raise notice 'request_data Generated insert: %', stmt;
        EXECUTE stmt;

EXCEPTION
        WHEN undefined_table THEN
        BEGIN
                PERFORM create_tbl_request_data(request_time_begin, request_service_id, request_monitoring);

                EXECUTE stmt;
        END;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.tr_request_data(request_time_begin timestamp without time zone, request_service_id integer, request_monitoring boolean, request_id bigint, content text, is_response boolean) OWNER TO fred;

--
-- Name: tr_request_object_ref(bigint, timestamp without time zone, integer, boolean, bigint, integer, integer); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION tr_request_object_ref(id bigint, request_time_begin timestamp without time zone, request_service_id integer, request_monitoring boolean, request_id bigint, object_type_id integer, object_id integer) RETURNS void
    AS $$
DECLARE
        table_name VARCHAR(50);
        stmt TEXT;
BEGIN
        table_name := quote_ident('request_object_ref_' || partition_postfix(request_time_begin, request_service_id, request_monitoring));
        stmt := 'INSERT INTO ' || table_name || ' (id, request_time_begin, request_service_id, request_monitoring, request_id, object_type_id, object_id) VALUES ('
            || COALESCE(id::TEXT, 'NULL')                       || ', '
            || COALESCE(quote_literal(request_time_begin), 'NULL') || ', '
            || COALESCE(request_service_id::TEXT, 'NULL')       || ', '
            || '''' || bool_to_str(request_monitoring)          || ''', '
            || COALESCE(request_id::TEXT, 'NULL')               || ', '
            || COALESCE(object_type_id::TEXT, 'NULL')           || ', '
            || COALESCE(object_id::TEXT, 'NULL')
            || ') ';

        raise notice 'generated SQL: %', stmt;
        EXECUTE stmt;
EXCEPTION
        WHEN undefined_table THEN
        BEGIN
                raise notice 'In exception handler..... ';
                PERFORM create_tbl_request_object_ref(request_time_begin, request_service_id, request_monitoring);
                EXECUTE stmt;
        END;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.tr_request_object_ref(id bigint, request_time_begin timestamp without time zone, request_service_id integer, request_monitoring boolean, request_id bigint, object_type_id integer, object_id integer) OWNER TO fred;

--
-- Name: tr_request_property_value(timestamp without time zone, integer, boolean, bigint, bigint, integer, text, boolean, bigint); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION tr_request_property_value(request_time_begin timestamp without time zone, request_service_id integer, request_monitoring boolean, id bigint, request_id bigint, property_name_id integer, value text, output boolean, parent_id bigint) RETURNS void
    AS $$
DECLARE
        table_name VARCHAR(50);
        stmt  TEXT;
BEGIN
        table_name := quote_ident( 'request_property_value_' || partition_postfix(request_time_begin, request_service_id, request_monitoring));
        stmt := 'INSERT INTO ' || table_name || '(request_time_begin, request_service_id, request_monitoring, id, request_id, property_name_id, value, output, parent_id) VALUES ('
            || COALESCE(quote_literal(request_time_begin), 'NULL')    || ', '
            || COALESCE(request_service_id::TEXT, 'NULL')                || ', '
            || '''' || bool_to_str(request_monitoring)                || ''', '
            || COALESCE(id::TEXT, 'NULL')                           || ', '
            || COALESCE(request_id::TEXT, 'NULL')                     || ', '
            || COALESCE(property_name_id::TEXT, 'NULL')                      || ', '
            || COALESCE(quote_literal(value), 'NULL')               || ', '
            || COALESCE('''' || bool_to_str(output) || '''', 'NULL') || ', '
            || COALESCE(parent_id::TEXT, 'NULL')                    || ')';
        -- raise notice 'request_property_value Generated insert: %', stmt;
        EXECUTE stmt;

EXCEPTION
        WHEN undefined_table THEN
        BEGIN
                PERFORM create_tbl_request_property_value(request_time_begin, request_service_id, request_monitoring);

                EXECUTE stmt;
        END;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.tr_request_property_value(request_time_begin timestamp without time zone, request_service_id integer, request_monitoring boolean, id bigint, request_id bigint, property_name_id integer, value text, output boolean, parent_id bigint) OWNER TO fred;

--
-- Name: tr_session(bigint, character varying, integer, timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION tr_session(id bigint, user_name character varying, user_id integer, login_date timestamp without time zone, logout_date timestamp without time zone) RETURNS void
    AS $$
DECLARE
        table_name VARCHAR(50);
        stmt  TEXT;
BEGIN
        table_name := quote_ident('session_' || partition_postfix(login_date, -1, false));
        stmt := 'INSERT INTO ' || table_name || ' (id, user_name, user_id, login_date, logout_date) VALUES ('
                || COALESCE(id::TEXT, 'NULL')           || ', '
                || COALESCE(quote_literal(user_name), 'NULL')                 || ', '
                || COALESCE(user_id::TEXT, 'NULL')                       || ', '
                || COALESCE(quote_literal(login_date), 'NULL')           || ', '
                || COALESCE(quote_literal(logout_date), 'NULL')

                || ')';

        -- raise notice 'session Generated insert: %', stmt;
        EXECUTE stmt;

EXCEPTION
        WHEN undefined_table THEN
        BEGIN
                PERFORM create_tbl_session(login_date);

                EXECUTE stmt;
        END;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.tr_session(id bigint, user_name character varying, user_id integer, login_date timestamp without time zone, logout_date timestamp without time zone) OWNER TO fred;

--
-- Name: update_object_states(integer); Type: FUNCTION; Schema: public; Owner: fred
--

CREATE FUNCTION update_object_states(integer) RETURNS void
    AS $_$
BEGIN
  IF NOT EXISTS(
    SELECT relname FROM pg_class
    WHERE relname = 'tmp_object_state_change' AND relkind = 'r' AND
    pg_table_is_visible(oid)
  )
  THEN
    CREATE TEMPORARY TABLE tmp_object_state_change (
      object_id INTEGER,
      object_hid INTEGER,
      new_states INTEGER[],
      old_states INTEGER[]
    );
  ELSE
    TRUNCATE tmp_object_state_change;
  END IF;

  IF $1 = 0
  THEN
    INSERT INTO tmp_object_state_change
    SELECT
      st.object_id, st.object_hid, st.states AS new_states,
      COALESCE(o.states,'{}') AS old_states
    FROM (
      SELECT * FROM domain_states
      UNION
      SELECT * FROM contact_states
      UNION
      SELECT * FROM nsset_states
      UNION
      SELECT * FROM keyset_states
    ) AS st
    LEFT JOIN object_state_now o ON (st.object_id=o.object_id)
    WHERE array_sort_dist(st.states)!=COALESCE(array_sort_dist(o.states),'{}');
  ELSE
    -- domain
    INSERT INTO tmp_object_state_change
    SELECT
      st.object_id, st.object_hid, st.states AS new_states,
      COALESCE(o.states,'{}') AS old_states
    FROM domain_states st
    LEFT JOIN object_state_now o ON (st.object_id=o.object_id)
    WHERE array_sort_dist(st.states)!=COALESCE(array_sort_dist(o.states),'{}')
    AND st.object_id=$1;
    -- contact
    INSERT INTO tmp_object_state_change
    SELECT
      st.object_id, st.object_hid, st.states AS new_states,
      COALESCE(o.states,'{}') AS old_states
    FROM contact_states st
    LEFT JOIN object_state_now o ON (st.object_id=o.object_id)
    WHERE array_sort_dist(st.states)!=COALESCE(array_sort_dist(o.states),'{}')
    AND st.object_id=$1;
    -- nsset
    INSERT INTO tmp_object_state_change
    SELECT
      st.object_id, st.object_hid, st.states AS new_states,
      COALESCE(o.states,'{}') AS old_states
    FROM nsset_states st
    LEFT JOIN object_state_now o ON (st.object_id=o.object_id)
    WHERE array_sort_dist(st.states)!=COALESCE(array_sort_dist(o.states),'{}')
    AND st.object_id=$1;
    -- keyset
    INSERT INTO tmp_object_state_change
    SELECT
      st.object_id, st.object_hid, st.states AS new_states,
      COALESCE(o.states,'{}') AS old_states
    FROM keyset_states st
    LEFT JOIN object_state_now o ON (st.object_id=o.object_id)
    WHERE array_sort_dist(st.states)!=COALESCE(array_sort_dist(o.states),'{}')
    AND st.object_id=$1;
  END IF;

  INSERT INTO object_state (object_id,state_id,valid_from,ohid_from)
  SELECT c.object_id,e.id,CURRENT_TIMESTAMP,c.object_hid
  FROM tmp_object_state_change c, enum_object_states e
  WHERE e.id = ANY(c.new_states) AND e.id != ALL(c.old_states);

  UPDATE object_state SET valid_to=CURRENT_TIMESTAMP, ohid_to=c.object_hid
  FROM enum_object_states e, tmp_object_state_change c
  WHERE e.id = ANY(c.old_states) AND e.id != ALL(c.new_states)
  AND e.id=object_state.state_id and c.object_id=object_state.object_id
  AND object_state.valid_to ISNULL;
END;
$_$
    LANGUAGE plpgsql;


ALTER FUNCTION public.update_object_states(integer) OWNER TO fred;

--
-- Name: array_accum(anyelement); Type: AGGREGATE; Schema: public; Owner: fred
--

CREATE AGGREGATE array_accum(anyelement) (
    SFUNC = array_append,
    STYPE = anyarray,
    INITCOND = '{}'
);


ALTER AGGREGATE public.array_accum(anyelement) OWNER TO fred;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: bank_account; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE bank_account (
    id integer NOT NULL,
    zone integer,
    account_number character(16) NOT NULL,
    account_name character(20),
    bank_code character(4),
    balance numeric(10,2) DEFAULT 0.0,
    last_date date,
    last_num integer
);


ALTER TABLE public.bank_account OWNER TO fred;

--
-- Name: TABLE bank_account; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE bank_account IS 'This table contains information about registry administrator bank account';


--
-- Name: COLUMN bank_account.id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_account.id IS 'unique automatically generated identifier';


--
-- Name: COLUMN bank_account.zone; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_account.zone IS 'for which zone should be account executed';


--
-- Name: COLUMN bank_account.balance; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_account.balance IS 'actual balance';


--
-- Name: COLUMN bank_account.last_date; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_account.last_date IS 'date of last statement';


--
-- Name: COLUMN bank_account.last_num; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_account.last_num IS 'number of last statement';


--
-- Name: bank_account_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE bank_account_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.bank_account_id_seq OWNER TO fred;

--
-- Name: bank_account_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE bank_account_id_seq OWNED BY bank_account.id;


--
-- Name: bank_account_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('bank_account_id_seq', 8, true);


--
-- Name: bank_payment; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE bank_payment (
    id integer NOT NULL,
    statement_id integer,
    account_id integer,
    account_number text NOT NULL,
    bank_code character varying(4) NOT NULL,
    code integer,
    type integer DEFAULT 1 NOT NULL,
    status integer,
    konstsym character varying(10),
    varsymb character varying(10),
    specsymb character varying(10),
    price numeric(10,2) NOT NULL,
    account_evid character varying(20),
    account_date date NOT NULL,
    account_memo character varying(64),
    account_name character varying(64),
    crtime timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.bank_payment OWNER TO fred;

--
-- Name: COLUMN bank_payment.id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_payment.id IS 'unique automatically generated identifier';


--
-- Name: COLUMN bank_payment.statement_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_payment.statement_id IS 'link to statement head';


--
-- Name: COLUMN bank_payment.account_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_payment.account_id IS 'link to account table';


--
-- Name: COLUMN bank_payment.account_number; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_payment.account_number IS 'contra-account number from which came or was sent a payment';


--
-- Name: COLUMN bank_payment.bank_code; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_payment.bank_code IS 'contra-account bank code';


--
-- Name: COLUMN bank_payment.code; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_payment.code IS 'operation code (1-debet item, 2-credit item, 4-cancel debet, 5-cancel credit)';


--
-- Name: COLUMN bank_payment.type; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_payment.type IS 'transfer type (1-not decided (not processed), 2-from/to registrar, 3-from/to bank, 4-between our own accounts, 5-related to academia, 6-other transfers';


--
-- Name: COLUMN bank_payment.status; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_payment.status IS 'payment status (1-Realized (only this should be further processed), 2-Partially realized, 3-Not realized, 4-Suspended, 5-Ended, 6-Waiting for clearing )';


--
-- Name: COLUMN bank_payment.konstsym; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_payment.konstsym IS 'constant symbol (contains bank code too)';


--
-- Name: COLUMN bank_payment.varsymb; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_payment.varsymb IS 'variable symbol';


--
-- Name: COLUMN bank_payment.specsymb; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_payment.specsymb IS 'spec symbol';


--
-- Name: COLUMN bank_payment.price; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_payment.price IS 'applied positive(credit) or negative(debet) amount';


--
-- Name: COLUMN bank_payment.account_evid; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_payment.account_evid IS 'account evidence';


--
-- Name: COLUMN bank_payment.account_date; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_payment.account_date IS 'accounting date';


--
-- Name: COLUMN bank_payment.account_memo; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_payment.account_memo IS 'note';


--
-- Name: COLUMN bank_payment.account_name; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_payment.account_name IS 'account name';


--
-- Name: COLUMN bank_payment.crtime; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_payment.crtime IS 'create timestamp';


--
-- Name: bank_payment_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE bank_payment_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.bank_payment_id_seq OWNER TO fred;

--
-- Name: bank_payment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE bank_payment_id_seq OWNED BY bank_payment.id;


--
-- Name: bank_payment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('bank_payment_id_seq', 6, true);


--
-- Name: bank_payment_registrar_credit_transaction_map; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE bank_payment_registrar_credit_transaction_map (
    id bigint NOT NULL,
    bank_payment_id bigint NOT NULL,
    registrar_credit_transaction_id bigint NOT NULL
);


ALTER TABLE public.bank_payment_registrar_credit_transaction_map OWNER TO fred;

--
-- Name: TABLE bank_payment_registrar_credit_transaction_map; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE bank_payment_registrar_credit_transaction_map IS 'payment assigned to credit items';


--
-- Name: bank_payment_registrar_credit_transaction_map_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE bank_payment_registrar_credit_transaction_map_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.bank_payment_registrar_credit_transaction_map_id_seq OWNER TO fred;

--
-- Name: bank_payment_registrar_credit_transaction_map_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE bank_payment_registrar_credit_transaction_map_id_seq OWNED BY bank_payment_registrar_credit_transaction_map.id;


--
-- Name: bank_payment_registrar_credit_transaction_map_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('bank_payment_registrar_credit_transaction_map_id_seq', 6, true);


--
-- Name: bank_statement; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE bank_statement (
    id integer NOT NULL,
    account_id integer,
    num integer,
    create_date date,
    balance_old_date date,
    balance_old numeric(10,2),
    balance_new numeric(10,2),
    balance_credit numeric(10,2),
    balance_debet numeric(10,2),
    file_id integer
);


ALTER TABLE public.bank_statement OWNER TO fred;

--
-- Name: COLUMN bank_statement.id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_statement.id IS 'unique automatically generated identifier';


--
-- Name: COLUMN bank_statement.account_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_statement.account_id IS 'link to used bank account';


--
-- Name: COLUMN bank_statement.num; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_statement.num IS 'statements number';


--
-- Name: COLUMN bank_statement.create_date; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_statement.create_date IS 'statement creation date';


--
-- Name: COLUMN bank_statement.balance_old; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_statement.balance_old IS 'old balance state';


--
-- Name: COLUMN bank_statement.balance_credit; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_statement.balance_credit IS 'income during statement';


--
-- Name: COLUMN bank_statement.balance_debet; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_statement.balance_debet IS 'expenses during statement';


--
-- Name: COLUMN bank_statement.file_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN bank_statement.file_id IS 'xml file identifier number';


--
-- Name: bank_statement_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE bank_statement_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.bank_statement_id_seq OWNER TO fred;

--
-- Name: bank_statement_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE bank_statement_id_seq OWNED BY bank_statement.id;


--
-- Name: bank_statement_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('bank_statement_id_seq', 6, true);


--
-- Name: check_dependance; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE check_dependance (
    id integer NOT NULL,
    addictid integer,
    testid integer
);


ALTER TABLE public.check_dependance OWNER TO fred;

--
-- Name: check_dependance_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE check_dependance_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.check_dependance_id_seq OWNER TO fred;

--
-- Name: check_dependance_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE check_dependance_id_seq OWNED BY check_dependance.id;


--
-- Name: check_dependance_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('check_dependance_id_seq', 16, true);


--
-- Name: check_nsset; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE check_nsset (
    id integer NOT NULL,
    nsset_hid integer,
    checkdate timestamp without time zone DEFAULT now() NOT NULL,
    reason smallint DEFAULT 0 NOT NULL,
    overallstatus smallint NOT NULL,
    extra_fqdns character varying(300)[],
    dig boolean NOT NULL,
    attempt smallint DEFAULT 1 NOT NULL
);


ALTER TABLE public.check_nsset OWNER TO fred;

--
-- Name: check_nsset_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE check_nsset_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.check_nsset_id_seq OWNER TO fred;

--
-- Name: check_nsset_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE check_nsset_id_seq OWNED BY check_nsset.id;


--
-- Name: check_nsset_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('check_nsset_id_seq', 1, false);


--
-- Name: check_result; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE check_result (
    id integer NOT NULL,
    checkid integer,
    testid integer,
    status smallint NOT NULL,
    note text,
    data text
);


ALTER TABLE public.check_result OWNER TO fred;

--
-- Name: check_result_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE check_result_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.check_result_id_seq OWNER TO fred;

--
-- Name: check_result_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE check_result_id_seq OWNED BY check_result.id;


--
-- Name: check_result_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('check_result_id_seq', 1, false);


--
-- Name: check_test; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE check_test (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    severity smallint NOT NULL,
    description character varying(300) NOT NULL,
    disabled boolean DEFAULT false NOT NULL,
    script character varying(300) NOT NULL,
    need_domain smallint DEFAULT 0 NOT NULL
);


ALTER TABLE public.check_test OWNER TO fred;

--
-- Name: comm_type; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE comm_type (
    id integer NOT NULL,
    type character varying(64)
);


ALTER TABLE public.comm_type OWNER TO fred;

--
-- Name: TABLE comm_type; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE comm_type IS 'type of communication with contact';


--
-- Name: comm_type_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE comm_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.comm_type_id_seq OWNER TO fred;

--
-- Name: comm_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE comm_type_id_seq OWNED BY comm_type.id;


--
-- Name: comm_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('comm_type_id_seq', 1, false);


--
-- Name: contact; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE contact (
    id integer NOT NULL,
    name character varying(1024),
    organization character varying(1024),
    street1 character varying(1024),
    street2 character varying(1024),
    street3 character varying(1024),
    city character varying(1024),
    stateorprovince character varying(1024),
    postalcode character varying(32),
    country character(2),
    telephone character varying(64),
    fax character varying(64),
    email character varying(1024),
    disclosename boolean DEFAULT false NOT NULL,
    discloseorganization boolean DEFAULT false NOT NULL,
    discloseaddress boolean DEFAULT false NOT NULL,
    disclosetelephone boolean DEFAULT false NOT NULL,
    disclosefax boolean DEFAULT false NOT NULL,
    discloseemail boolean DEFAULT false NOT NULL,
    notifyemail character varying(1024),
    vat character varying(32),
    ssn character varying(64),
    ssntype integer,
    disclosevat boolean DEFAULT false NOT NULL,
    discloseident boolean DEFAULT false NOT NULL,
    disclosenotifyemail boolean DEFAULT false NOT NULL
);


ALTER TABLE public.contact OWNER TO fred;

--
-- Name: TABLE contact; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE contact IS 'List of contacts which act in registry as domain owners and administrative contacts for nameservers group';


--
-- Name: COLUMN contact.id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN contact.id IS 'references into object table';


--
-- Name: COLUMN contact.name; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN contact.name IS 'name of contact person';


--
-- Name: COLUMN contact.organization; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN contact.organization IS 'full trade name of organization';


--
-- Name: COLUMN contact.street1; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN contact.street1 IS 'part of address';


--
-- Name: COLUMN contact.street2; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN contact.street2 IS 'part of address';


--
-- Name: COLUMN contact.street3; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN contact.street3 IS 'part of address';


--
-- Name: COLUMN contact.city; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN contact.city IS 'part of address - city';


--
-- Name: COLUMN contact.stateorprovince; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN contact.stateorprovince IS 'part of address - region';


--
-- Name: COLUMN contact.postalcode; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN contact.postalcode IS 'part of address - postal code';


--
-- Name: COLUMN contact.country; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN contact.country IS 'two character country code (e.g. cz) from enum_country table';


--
-- Name: COLUMN contact.telephone; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN contact.telephone IS 'telephone number';


--
-- Name: COLUMN contact.fax; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN contact.fax IS 'fax number';


--
-- Name: COLUMN contact.email; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN contact.email IS 'email address';


--
-- Name: COLUMN contact.disclosename; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN contact.disclosename IS 'whether reveal contact name';


--
-- Name: COLUMN contact.discloseorganization; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN contact.discloseorganization IS 'whether reveal organization';


--
-- Name: COLUMN contact.discloseaddress; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN contact.discloseaddress IS 'whether reveal address';


--
-- Name: COLUMN contact.disclosetelephone; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN contact.disclosetelephone IS 'whether reveal phone number';


--
-- Name: COLUMN contact.disclosefax; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN contact.disclosefax IS 'whether reveal fax number';


--
-- Name: COLUMN contact.discloseemail; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN contact.discloseemail IS 'whether reveal email address';


--
-- Name: COLUMN contact.notifyemail; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN contact.notifyemail IS 'to this email address will be send message in case of any change in domain or nsset affecting contact';


--
-- Name: COLUMN contact.vat; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN contact.vat IS 'tax number';


--
-- Name: COLUMN contact.ssn; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN contact.ssn IS 'unambiguous identification number (e.g. Social Security number, identity card number, date of birth)';


--
-- Name: COLUMN contact.ssntype; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN contact.ssntype IS 'type of identification number from enum_ssntype table';


--
-- Name: COLUMN contact.disclosevat; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN contact.disclosevat IS 'whether reveal VAT number';


--
-- Name: COLUMN contact.discloseident; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN contact.discloseident IS 'whether reveal SSN number';


--
-- Name: COLUMN contact.disclosenotifyemail; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN contact.disclosenotifyemail IS 'whether reveal notify email';


--
-- Name: contact_history; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE contact_history (
    historyid integer NOT NULL,
    id integer,
    name character varying(1024),
    organization character varying(1024),
    street1 character varying(1024),
    street2 character varying(1024),
    street3 character varying(1024),
    city character varying(1024),
    stateorprovince character varying(1024),
    postalcode character varying(32),
    country character(2),
    telephone character varying(64),
    fax character varying(64),
    email character varying(1024),
    disclosename boolean DEFAULT false NOT NULL,
    discloseorganization boolean DEFAULT false NOT NULL,
    discloseaddress boolean DEFAULT false NOT NULL,
    disclosetelephone boolean DEFAULT false NOT NULL,
    disclosefax boolean DEFAULT false NOT NULL,
    discloseemail boolean DEFAULT false NOT NULL,
    notifyemail character varying(1024),
    vat character varying(32),
    ssn character varying(64),
    ssntype integer,
    disclosevat boolean DEFAULT false NOT NULL,
    discloseident boolean DEFAULT false NOT NULL,
    disclosenotifyemail boolean DEFAULT false NOT NULL
);


ALTER TABLE public.contact_history OWNER TO fred;

--
-- Name: TABLE contact_history; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE contact_history IS 'Historic data from contact table.
creation - actual data will be copied here from original table in case of any change in contact table';


--
-- Name: domain; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE domain (
    id integer NOT NULL,
    zone integer,
    registrant integer NOT NULL,
    nsset integer,
    exdate date NOT NULL,
    keyset integer
);


ALTER TABLE public.domain OWNER TO fred;

--
-- Name: TABLE domain; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE domain IS 'Evidence of domains';


--
-- Name: COLUMN domain.id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN domain.id IS 'point to object table';


--
-- Name: COLUMN domain.zone; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN domain.zone IS 'zone in which domain belong';


--
-- Name: COLUMN domain.registrant; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN domain.registrant IS 'domain owner';


--
-- Name: COLUMN domain.nsset; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN domain.nsset IS 'link to nameserver set, can be NULL (when is domain registered withou nsset)';


--
-- Name: COLUMN domain.exdate; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN domain.exdate IS 'domain expiry date';


--
-- Name: COLUMN domain.keyset; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN domain.keyset IS 'reference to used keyset';


--
-- Name: domain_contact_map; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE domain_contact_map (
    domainid integer NOT NULL,
    contactid integer NOT NULL,
    role integer DEFAULT 1 NOT NULL
);


ALTER TABLE public.domain_contact_map OWNER TO fred;

--
-- Name: enum_parameters; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE enum_parameters (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    val character varying(100) NOT NULL
);


ALTER TABLE public.enum_parameters OWNER TO fred;

--
-- Name: TABLE enum_parameters; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE enum_parameters IS 'Table of system operational parameters.
Meanings of parameters:

1 - model version - for checking data model version and for applying upgrade scripts
2 - tld list version - for updating table enum_tlds by data from url
3 - expiration notify period - used to change state of domain to unguarded and remove domain from DNS,
    value is number of days relative to date domain.exdate
4 - expiration dns protection period - same as parameter 3
5 - expiration letter warning period - used to change state of domain to deleteWarning and generate letter
    witch warning
6 - expiration registration protection period - used to change state of domain to deleteCandidate and
    unregister domain from system
7 - validation notify 1 period - used to change state of domain to validationWarning1 and send poll
    message to registrar
8 - validation notify 2 period - used to change state of domain to validationWarning2 and send
    email to registrant
9 - regular day procedure period - used to identify hout when objects are deleted and domains
    are moving outzone
10 - regular day procedure zone - used to identify time zone in which parameter 9 is specified';


--
-- Name: COLUMN enum_parameters.id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN enum_parameters.id IS 'primary identification';


--
-- Name: COLUMN enum_parameters.name; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN enum_parameters.name IS 'descriptive name of parameter - for information uses only';


--
-- Name: COLUMN enum_parameters.val; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN enum_parameters.val IS 'value of parameter';


--
-- Name: keyset_contact_map; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE keyset_contact_map (
    keysetid integer NOT NULL,
    contactid integer NOT NULL
);


ALTER TABLE public.keyset_contact_map OWNER TO fred;

--
-- Name: nsset_contact_map; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE nsset_contact_map (
    nssetid integer NOT NULL,
    contactid integer NOT NULL
);


ALTER TABLE public.nsset_contact_map OWNER TO fred;

--
-- Name: object; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE object (
    id integer NOT NULL,
    clid integer NOT NULL,
    upid integer,
    trdate timestamp without time zone,
    update timestamp without time zone,
    authinfopw character varying(300)
);


ALTER TABLE public.object OWNER TO fred;

--
-- Name: object_registry; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE object_registry (
    id integer NOT NULL,
    roid character varying(255) NOT NULL,
    type smallint,
    name character varying(255) NOT NULL,
    crid integer NOT NULL,
    crdate timestamp without time zone DEFAULT now() NOT NULL,
    erdate timestamp without time zone,
    crhistoryid integer,
    historyid integer
);


ALTER TABLE public.object_registry OWNER TO fred;

--
-- Name: COLUMN object_registry.id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN object_registry.id IS 'unique automatically generated identifier';


--
-- Name: COLUMN object_registry.roid; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN object_registry.roid IS 'unique roid';


--
-- Name: COLUMN object_registry.type; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN object_registry.type IS 'object type (1-contact, 2-nsset, 3-domain)';


--
-- Name: COLUMN object_registry.name; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN object_registry.name IS 'handle of fqdn';


--
-- Name: COLUMN object_registry.crid; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN object_registry.crid IS 'link to registrar';


--
-- Name: COLUMN object_registry.crdate; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN object_registry.crdate IS 'object creation date and time';


--
-- Name: COLUMN object_registry.erdate; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN object_registry.erdate IS 'object erase date';


--
-- Name: COLUMN object_registry.crhistoryid; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN object_registry.crhistoryid IS 'link into create history';


--
-- Name: COLUMN object_registry.historyid; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN object_registry.historyid IS 'link to last change in history';


--
-- Name: object_state; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE object_state (
    id integer NOT NULL,
    object_id integer NOT NULL,
    state_id integer NOT NULL,
    valid_from timestamp without time zone NOT NULL,
    valid_to timestamp without time zone,
    ohid_from integer,
    ohid_to integer
);


ALTER TABLE public.object_state OWNER TO fred;

--
-- Name: TABLE object_state; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE object_state IS 'main table of object states and their changes';


--
-- Name: COLUMN object_state.object_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN object_state.object_id IS 'id of object that has this new status';


--
-- Name: COLUMN object_state.state_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN object_state.state_id IS 'id of status';


--
-- Name: COLUMN object_state.valid_from; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN object_state.valid_from IS 'date and time when object entered state';


--
-- Name: COLUMN object_state.valid_to; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN object_state.valid_to IS 'date and time when object leaved state or null if still has this status';


--
-- Name: COLUMN object_state.ohid_from; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN object_state.ohid_from IS 'history id of object in the moment of entering state (may be null)';


--
-- Name: COLUMN object_state.ohid_to; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN object_state.ohid_to IS 'history id of object in the moment of leaving state or null';


--
-- Name: object_state_request; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE object_state_request (
    id integer NOT NULL,
    object_id integer NOT NULL,
    state_id integer NOT NULL,
    valid_from timestamp without time zone DEFAULT now() NOT NULL,
    valid_to timestamp without time zone,
    crdate timestamp without time zone DEFAULT now() NOT NULL,
    canceled timestamp without time zone
);


ALTER TABLE public.object_state_request OWNER TO fred;

--
-- Name: TABLE object_state_request; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE object_state_request IS 'request for setting manual state';


--
-- Name: COLUMN object_state_request.object_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN object_state_request.object_id IS 'id of object gaining request state';


--
-- Name: COLUMN object_state_request.state_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN object_state_request.state_id IS 'id of requested state';


--
-- Name: COLUMN object_state_request.valid_from; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN object_state_request.valid_from IS 'when object should enter requested state';


--
-- Name: COLUMN object_state_request.valid_to; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN object_state_request.valid_to IS 'when object should leave requested state';


--
-- Name: COLUMN object_state_request.crdate; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN object_state_request.crdate IS 'could be pointed to some list of administation action';


--
-- Name: COLUMN object_state_request.canceled; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN object_state_request.canceled IS 'could be pointed to some list of administation action';


--
-- Name: object_state_request_now; Type: VIEW; Schema: public; Owner: fred
--

CREATE VIEW object_state_request_now AS
    SELECT object_state_request.object_id, array_accum(object_state_request.state_id) AS states FROM object_state_request WHERE (((object_state_request.valid_from <= now()) AND ((object_state_request.valid_to IS NULL) OR (object_state_request.valid_to >= now()))) AND (object_state_request.canceled IS NULL)) GROUP BY object_state_request.object_id;


ALTER TABLE public.object_state_request_now OWNER TO fred;

--
-- Name: contact_states; Type: VIEW; Schema: public; Owner: fred
--

CREATE VIEW contact_states AS
    SELECT o.id AS object_id, o.historyid AS object_hid, ((COALESCE(osr.states, '{}'::integer[]) || CASE WHEN (NOT (cl.cid IS NULL)) THEN ARRAY[16] ELSE '{}'::integer[] END) || CASE WHEN (((cl.cid IS NULL) AND date_month_test(GREATEST((COALESCE(l.last_linked, o.crdate))::date, (COALESCE(ob.update, o.crdate))::date), ep_mn.val, ep_tm.val, ep_tz.val)) AND (NOT (1 = ANY (COALESCE(osr.states, '{}'::integer[]))))) THEN ARRAY[17] ELSE '{}'::integer[] END) AS states FROM (((((((object ob JOIN object_registry o ON (((ob.id = o.id) AND (o.type = 1)))) JOIN enum_parameters ep_tm ON ((ep_tm.id = 9))) JOIN enum_parameters ep_tz ON ((ep_tz.id = 10))) JOIN enum_parameters ep_mn ON ((ep_mn.id = 11))) LEFT JOIN (((SELECT domain.registrant AS cid FROM domain UNION SELECT domain_contact_map.contactid AS cid FROM domain_contact_map) UNION SELECT nsset_contact_map.contactid AS cid FROM nsset_contact_map) UNION SELECT keyset_contact_map.contactid AS cid FROM keyset_contact_map) cl ON ((o.id = cl.cid))) LEFT JOIN (SELECT object_state.object_id, max(object_state.valid_to) AS last_linked FROM object_state WHERE (object_state.state_id = 16) GROUP BY object_state.object_id) l ON ((o.id = l.object_id))) LEFT JOIN object_state_request_now osr ON ((o.id = osr.object_id)));


ALTER TABLE public.contact_states OWNER TO fred;

--
-- Name: dnskey; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE dnskey (
    id integer NOT NULL,
    keysetid integer NOT NULL,
    flags integer NOT NULL,
    protocol integer NOT NULL,
    alg integer NOT NULL,
    key text NOT NULL
);


ALTER TABLE public.dnskey OWNER TO fred;

--
-- Name: COLUMN dnskey.id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN dnskey.id IS 'unique automatically generated identifier';


--
-- Name: COLUMN dnskey.keysetid; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN dnskey.keysetid IS 'reference to relevant record in keyset table';


--
-- Name: COLUMN dnskey.protocol; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN dnskey.protocol IS 'must be 3';


--
-- Name: COLUMN dnskey.alg; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN dnskey.alg IS 'used algorithm (see http://rfc-ref.org/RFC-TEXTS/4034/chapter11.html for further details)';


--
-- Name: COLUMN dnskey.key; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN dnskey.key IS 'base64 decoded key';


--
-- Name: dnskey_history; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE dnskey_history (
    historyid integer NOT NULL,
    id integer NOT NULL,
    keysetid integer NOT NULL,
    flags integer NOT NULL,
    protocol integer NOT NULL,
    alg integer NOT NULL,
    key text NOT NULL
);


ALTER TABLE public.dnskey_history OWNER TO fred;

--
-- Name: TABLE dnskey_history; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE dnskey_history IS 'historic data from dnskey table';


--
-- Name: dnskey_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE dnskey_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.dnskey_id_seq OWNER TO fred;

--
-- Name: dnskey_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE dnskey_id_seq OWNED BY dnskey.id;


--
-- Name: dnskey_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('dnskey_id_seq', 10, true);


--
-- Name: dnssec; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE dnssec (
    domainid integer NOT NULL,
    keytag character varying(255) NOT NULL,
    alg smallint NOT NULL,
    digesttype smallint NOT NULL,
    digest character varying(255) NOT NULL,
    maxsiglive interval,
    keyflags bit(16),
    keyprotocol smallint,
    keyalg smallint,
    pubkey character varying(1024),
    CONSTRAINT dnssec_alg_check CHECK (((alg >= 0) AND (alg <= 255))),
    CONSTRAINT dnssec_keyalg_check CHECK (((keyalg >= 0) AND (keyalg <= 255))),
    CONSTRAINT dnssec_keyflags_check CHECK (((B'1000000010000000'::"bit" & keyflags) = keyflags)),
    CONSTRAINT dnssec_keyprotocol_check CHECK ((keyprotocol = 3))
);


ALTER TABLE public.dnssec OWNER TO fred;

--
-- Name: domain_blacklist; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE domain_blacklist (
    id integer NOT NULL,
    regexp character varying(255) NOT NULL,
    valid_from timestamp without time zone NOT NULL,
    valid_to timestamp without time zone,
    reason character varying(255) NOT NULL,
    creator integer
);


ALTER TABLE public.domain_blacklist OWNER TO fred;

--
-- Name: COLUMN domain_blacklist.regexp; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN domain_blacklist.regexp IS 'regular expression which is blocked';


--
-- Name: COLUMN domain_blacklist.valid_from; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN domain_blacklist.valid_from IS 'from when is block valid';


--
-- Name: COLUMN domain_blacklist.valid_to; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN domain_blacklist.valid_to IS 'till when is block valid, if it is NULL, it is not restricted';


--
-- Name: COLUMN domain_blacklist.reason; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN domain_blacklist.reason IS 'reason why is domain blocked';


--
-- Name: COLUMN domain_blacklist.creator; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN domain_blacklist.creator IS 'who created this record. If it is NULL, it is system record created as a part of system configuration';


--
-- Name: domain_blacklist_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE domain_blacklist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.domain_blacklist_id_seq OWNER TO fred;

--
-- Name: domain_blacklist_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE domain_blacklist_id_seq OWNED BY domain_blacklist.id;


--
-- Name: domain_blacklist_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('domain_blacklist_id_seq', 1, false);


--
-- Name: domain_contact_map_history; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE domain_contact_map_history (
    historyid integer NOT NULL,
    domainid integer NOT NULL,
    contactid integer NOT NULL,
    role integer DEFAULT 1 NOT NULL
);


ALTER TABLE public.domain_contact_map_history OWNER TO fred;

--
-- Name: TABLE domain_contact_map_history; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE domain_contact_map_history IS 'Historic data from domain_contact_map table

creation - all contacts links which are linked to changed domain are copied here';


--
-- Name: domain_history; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE domain_history (
    historyid integer NOT NULL,
    zone integer,
    id integer,
    exdate date NOT NULL,
    registrant integer,
    nsset integer,
    keyset integer
);


ALTER TABLE public.domain_history OWNER TO fred;

--
-- Name: TABLE domain_history; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE domain_history IS 'Historic data from domain table

creation - in case of any change in domain table, including changes in bindings to other tables';


--
-- Name: enumval; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE enumval (
    domainid integer NOT NULL,
    exdate date NOT NULL,
    publish boolean DEFAULT false NOT NULL
);


ALTER TABLE public.enumval OWNER TO fred;

--
-- Name: domain_states; Type: VIEW; Schema: public; Owner: fred
--

CREATE VIEW domain_states AS
    SELECT d.id AS object_id, o.historyid AS object_hid, (((((((((((COALESCE(osr.states, '{}'::integer[]) || CASE WHEN (date_test(d.exdate, ep_ex_not.val) AND (NOT (2 = ANY (COALESCE(osr.states, '{}'::integer[]))))) THEN ARRAY[8] ELSE '{}'::integer[] END) || CASE WHEN (date_test(d.exdate, '0'::character varying) AND (NOT (2 = ANY (COALESCE(osr.states, '{}'::integer[]))))) THEN ARRAY[9] ELSE '{}'::integer[] END) || CASE WHEN (date_time_test(d.exdate, ep_ex_dns.val, ep_tm2.val, ep_tz.val) AND (NOT (2 = ANY (COALESCE(osr.states, '{}'::integer[]))))) THEN ARRAY[10] ELSE '{}'::integer[] END) || CASE WHEN date_test(e.exdate, ep_val_not1.val) THEN ARRAY[11] ELSE '{}'::integer[] END) || CASE WHEN date_test(e.exdate, ep_val_not2.val) THEN ARRAY[12] ELSE '{}'::integer[] END) || CASE WHEN date_time_test(e.exdate, '0'::character varying, ep_tm2.val, ep_tz.val) THEN ARRAY[13] ELSE '{}'::integer[] END) || CASE WHEN (d.nsset IS NULL) THEN ARRAY[14] ELSE '{}'::integer[] END) || CASE WHEN (((d.nsset IS NULL) OR (5 = ANY (COALESCE(osr.states, '{}'::integer[])))) OR (((date_time_test(d.exdate, ep_ex_dns.val, ep_tm2.val, ep_tz.val) AND (NOT (2 = ANY (COALESCE(osr.states, '{}'::integer[]))))) OR date_time_test(e.exdate, '0'::character varying, ep_tm2.val, ep_tz.val)) AND (NOT (6 = ANY (COALESCE(osr.states, '{}'::integer[])))))) THEN ARRAY[15] ELSE '{}'::integer[] END) || CASE WHEN ((date_time_test(d.exdate, ep_ex_reg.val, ep_tm.val, ep_tz.val) AND (NOT (2 = ANY (COALESCE(osr.states, '{}'::integer[]))))) AND (NOT (1 = ANY (COALESCE(osr.states, '{}'::integer[]))))) THEN ARRAY[17] ELSE '{}'::integer[] END) || CASE WHEN (date_test(d.exdate, ep_ex_let.val) AND (NOT (2 = ANY (COALESCE(osr.states, '{}'::integer[]))))) THEN ARRAY[19] ELSE '{}'::integer[] END) || CASE WHEN ((date_time_test(d.exdate, ep_ex_dns.val, ep_tm2.val, ep_tz.val) AND (NOT (2 = ANY (COALESCE(osr.states, '{}'::integer[]))))) AND (NOT (6 = ANY (COALESCE(osr.states, '{}'::integer[]))))) THEN ARRAY[20] ELSE '{}'::integer[] END) AS states FROM object_registry o, (((((((((((domain d LEFT JOIN enumval e ON ((d.id = e.domainid))) LEFT JOIN object_state_request_now osr ON ((d.id = osr.object_id))) JOIN enum_parameters ep_ex_not ON ((ep_ex_not.id = 3))) JOIN enum_parameters ep_ex_dns ON ((ep_ex_dns.id = 4))) JOIN enum_parameters ep_ex_let ON ((ep_ex_let.id = 5))) JOIN enum_parameters ep_ex_reg ON ((ep_ex_reg.id = 6))) JOIN enum_parameters ep_val_not1 ON ((ep_val_not1.id = 7))) JOIN enum_parameters ep_val_not2 ON ((ep_val_not2.id = 8))) JOIN enum_parameters ep_tm ON ((ep_tm.id = 9))) JOIN enum_parameters ep_tz ON ((ep_tz.id = 10))) JOIN enum_parameters ep_tm2 ON ((ep_tm2.id = 14))) WHERE (d.id = o.id);


ALTER TABLE public.domain_states OWNER TO fred;

--
-- Name: domains_by_keyset_view; Type: VIEW; Schema: public; Owner: fred
--

CREATE VIEW domains_by_keyset_view AS
    SELECT domain.keyset, count(domain.keyset) AS number FROM domain WHERE (domain.keyset IS NOT NULL) GROUP BY domain.keyset;


ALTER TABLE public.domains_by_keyset_view OWNER TO fred;

--
-- Name: domains_by_nsset_view; Type: VIEW; Schema: public; Owner: fred
--

CREATE VIEW domains_by_nsset_view AS
    SELECT domain.nsset, count(domain.nsset) AS number FROM domain WHERE (domain.nsset IS NOT NULL) GROUP BY domain.nsset;


ALTER TABLE public.domains_by_nsset_view OWNER TO fred;

--
-- Name: dsrecord; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE dsrecord (
    id integer NOT NULL,
    keysetid integer NOT NULL,
    keytag integer NOT NULL,
    alg integer NOT NULL,
    digesttype integer NOT NULL,
    digest character varying(255) NOT NULL,
    maxsiglife integer
);


ALTER TABLE public.dsrecord OWNER TO fred;

--
-- Name: TABLE dsrecord; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE dsrecord IS 'table with DS resource records';


--
-- Name: COLUMN dsrecord.id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN dsrecord.id IS 'unique automatically generated identifier';


--
-- Name: COLUMN dsrecord.keysetid; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN dsrecord.keysetid IS 'reference to relevant record in Keyset table';


--
-- Name: COLUMN dsrecord.alg; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN dsrecord.alg IS 'used algorithm. See RFC 4034 appendix A.1 for list';


--
-- Name: COLUMN dsrecord.digesttype; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN dsrecord.digesttype IS 'used digest type. See RFC 4034 appendix A.2 for list';


--
-- Name: COLUMN dsrecord.digest; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN dsrecord.digest IS 'digest of DNSKEY';


--
-- Name: COLUMN dsrecord.maxsiglife; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN dsrecord.maxsiglife IS 'record TTL';


--
-- Name: dsrecord_history; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE dsrecord_history (
    historyid integer NOT NULL,
    id integer NOT NULL,
    keysetid integer NOT NULL,
    keytag integer NOT NULL,
    alg integer NOT NULL,
    digesttype integer NOT NULL,
    digest character varying(255) NOT NULL,
    maxsiglife integer
);


ALTER TABLE public.dsrecord_history OWNER TO fred;

--
-- Name: TABLE dsrecord_history; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE dsrecord_history IS 'historic data from DSRecord table';


--
-- Name: dsrecord_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE dsrecord_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.dsrecord_id_seq OWNER TO fred;

--
-- Name: dsrecord_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE dsrecord_id_seq OWNED BY dsrecord.id;


--
-- Name: dsrecord_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('dsrecord_id_seq', 1, false);


--
-- Name: enum_bank_code; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE enum_bank_code (
    code character(4) NOT NULL,
    name_short character varying(4) NOT NULL,
    name_full character varying(64) NOT NULL
);


ALTER TABLE public.enum_bank_code OWNER TO fred;

--
-- Name: TABLE enum_bank_code; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE enum_bank_code IS 'list of bank codes';


--
-- Name: COLUMN enum_bank_code.code; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN enum_bank_code.code IS 'bank code';


--
-- Name: COLUMN enum_bank_code.name_short; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN enum_bank_code.name_short IS 'bank name abbrevation';


--
-- Name: COLUMN enum_bank_code.name_full; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN enum_bank_code.name_full IS 'full bank name';


--
-- Name: enum_country; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE enum_country (
    id character(2) NOT NULL,
    country character varying(1024) NOT NULL,
    country_cs character varying(1024)
);


ALTER TABLE public.enum_country OWNER TO fred;

--
-- Name: TABLE enum_country; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE enum_country IS 'list of country codes and names';


--
-- Name: COLUMN enum_country.id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN enum_country.id IS 'country code (e.g. CZ for Czech republic)';


--
-- Name: COLUMN enum_country.country; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN enum_country.country IS 'english country name';


--
-- Name: COLUMN enum_country.country_cs; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN enum_country.country_cs IS 'optional country name in native language';


--
-- Name: enum_error; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE enum_error (
    id integer NOT NULL,
    status character varying(128) NOT NULL,
    status_cs character varying(128) NOT NULL
);


ALTER TABLE public.enum_error OWNER TO fred;

--
-- Name: TABLE enum_error; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE enum_error IS 'Table of error messages
id   - message
1000 - command completed successfully
1001 - command completed successfully, action pending
1300 - command completed successfully, no messages
1301 - command completed successfully, act to dequeue
1500 - command completed successfully, ending session
2000 - unknown command
2001 - command syntax error
2002 - command use error
2003 - required parameter missing
2004 - parameter value range error
2005 - parameter value systax error
2100 - unimplemented protocol version
2101 - unimplemented command
2102 - unimplemented option
2103 - unimplemented extension
2104 - billing failure
2105 - object is not eligible for renewal
2106 - object is not eligible for transfer
2200 - authentication error
2201 - authorization error
2202 - invalid authorization information
2300 - object pending transfer
2301 - object not pending transfer
2302 - object exists
2303 - object does not exists
2304 - object status prohibits operation
2305 - object association prohibits operation
2306 - parameter value policy error
2307 - unimplemented object service
2308 - data management policy violation
2400 - command failed
2500 - command failed, server closing connection
2501 - authentication error, server closing connection
2502 - session limit exceeded, server closing connection';


--
-- Name: COLUMN enum_error.id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN enum_error.id IS 'id of error';


--
-- Name: COLUMN enum_error.status; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN enum_error.status IS 'error message in english language';


--
-- Name: COLUMN enum_error.status_cs; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN enum_error.status_cs IS 'error message in native language';


--
-- Name: enum_error_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE enum_error_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.enum_error_id_seq OWNER TO fred;

--
-- Name: enum_error_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE enum_error_id_seq OWNED BY enum_error.id;


--
-- Name: enum_error_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('enum_error_id_seq', 2502, true);


--
-- Name: enum_filetype; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE enum_filetype (
    id smallint NOT NULL,
    name character varying(300)
);


ALTER TABLE public.enum_filetype OWNER TO fred;

--
-- Name: TABLE enum_filetype; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE enum_filetype IS 'list of file types

id - name
 1 - invoice pdf
 2 - invoice xml
 3 - accounting xml
 4 - banking statement
 5 - expiration warning letter';


--
-- Name: enum_object_states; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE enum_object_states (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    types integer[] NOT NULL,
    manual boolean NOT NULL,
    external boolean NOT NULL,
    importance integer
);


ALTER TABLE public.enum_object_states OWNER TO fred;

--
-- Name: TABLE enum_object_states; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE enum_object_states IS 'list of all supported status types';


--
-- Name: COLUMN enum_object_states.name; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN enum_object_states.name IS 'code name for status';


--
-- Name: COLUMN enum_object_states.types; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN enum_object_states.types IS 'what types of objects can have this status (object_registry.type list)';


--
-- Name: COLUMN enum_object_states.manual; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN enum_object_states.manual IS 'if this status is set manualy';


--
-- Name: COLUMN enum_object_states.external; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN enum_object_states.external IS 'if this status is exported to public';


--
-- Name: enum_object_states_desc; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE enum_object_states_desc (
    state_id integer NOT NULL,
    lang character(2) NOT NULL,
    description character varying(255)
);


ALTER TABLE public.enum_object_states_desc OWNER TO fred;

--
-- Name: TABLE enum_object_states_desc; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE enum_object_states_desc IS 'description for states in different languages';


--
-- Name: COLUMN enum_object_states_desc.lang; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN enum_object_states_desc.lang IS 'code of language';


--
-- Name: COLUMN enum_object_states_desc.description; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN enum_object_states_desc.description IS 'descriptive text';


--
-- Name: enum_operation; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE enum_operation (
    id integer NOT NULL,
    operation character varying(64) NOT NULL
);


ALTER TABLE public.enum_operation OWNER TO fred;

--
-- Name: TABLE enum_operation; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE enum_operation IS 'list of priced operation';


--
-- Name: COLUMN enum_operation.id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN enum_operation.id IS 'unique automatically generated identifier';


--
-- Name: COLUMN enum_operation.operation; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN enum_operation.operation IS 'operation';


--
-- Name: enum_operation_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE enum_operation_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.enum_operation_id_seq OWNER TO fred;

--
-- Name: enum_operation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE enum_operation_id_seq OWNED BY enum_operation.id;


--
-- Name: enum_operation_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('enum_operation_id_seq', 2, true);


--
-- Name: enum_public_request_status; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE enum_public_request_status (
    id integer NOT NULL,
    name character varying(32) NOT NULL,
    description character varying(128)
);


ALTER TABLE public.enum_public_request_status OWNER TO fred;

--
-- Name: enum_public_request_type; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE enum_public_request_type (
    id integer NOT NULL,
    name character varying(64) NOT NULL,
    description character varying(256)
);


ALTER TABLE public.enum_public_request_type OWNER TO fred;

--
-- Name: enum_reason; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE enum_reason (
    id integer NOT NULL,
    reason character varying(128) NOT NULL,
    reason_cs character varying(128) NOT NULL
);


ALTER TABLE public.enum_reason OWNER TO fred;

--
-- Name: TABLE enum_reason; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE enum_reason IS 'Table of error messages reason';


--
-- Name: COLUMN enum_reason.reason; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN enum_reason.reason IS 'reason in english language';


--
-- Name: COLUMN enum_reason.reason_cs; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN enum_reason.reason_cs IS 'reason in native language';


--
-- Name: enum_reason_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE enum_reason_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.enum_reason_id_seq OWNER TO fred;

--
-- Name: enum_reason_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE enum_reason_id_seq OWNED BY enum_reason.id;


--
-- Name: enum_reason_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('enum_reason_id_seq', 62, true);


--
-- Name: enum_send_status; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE enum_send_status (
    id integer NOT NULL,
    status_name character varying(64),
    description text
);


ALTER TABLE public.enum_send_status OWNER TO fred;

--
-- Name: TABLE enum_send_status; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE enum_send_status IS 'list of statuses when sending a general message to a contact';


--
-- Name: enum_ssntype; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE enum_ssntype (
    id integer NOT NULL,
    type character varying(8) NOT NULL,
    description character varying(64) NOT NULL
);


ALTER TABLE public.enum_ssntype OWNER TO fred;

--
-- Name: TABLE enum_ssntype; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE enum_ssntype IS 'Table of identification number types

types:
id - type   - description
 1 - RC     - born number
 2 - OP     - identity card number
 3 - PASS   - passport number
 4 - ICO    - organization identification number
 5 - MPSV   - social system identification
 6 - BIRTHDAY - day of birth';


--
-- Name: COLUMN enum_ssntype.type; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN enum_ssntype.type IS 'type abbrevation';


--
-- Name: COLUMN enum_ssntype.description; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN enum_ssntype.description IS 'type description';


--
-- Name: enum_ssntype_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE enum_ssntype_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.enum_ssntype_id_seq OWNER TO fred;

--
-- Name: enum_ssntype_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE enum_ssntype_id_seq OWNED BY enum_ssntype.id;


--
-- Name: enum_ssntype_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('enum_ssntype_id_seq', 6, true);


--
-- Name: enum_tlds; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE enum_tlds (
    tld character varying(64) NOT NULL
);


ALTER TABLE public.enum_tlds OWNER TO fred;

--
-- Name: TABLE enum_tlds; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE enum_tlds IS 'list of available tlds for checking of dns host tld';


--
-- Name: enumval_history; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE enumval_history (
    historyid integer NOT NULL,
    domainid integer,
    exdate date NOT NULL,
    publish boolean DEFAULT false NOT NULL
);


ALTER TABLE public.enumval_history OWNER TO fred;

--
-- Name: epp_info_buffer; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE epp_info_buffer (
    registrar_id integer NOT NULL,
    current integer
);


ALTER TABLE public.epp_info_buffer OWNER TO fred;

--
-- Name: epp_info_buffer_content; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE epp_info_buffer_content (
    id integer NOT NULL,
    registrar_id integer NOT NULL,
    object_id integer NOT NULL
);


ALTER TABLE public.epp_info_buffer_content OWNER TO fred;

--
-- Name: epp_login_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE epp_login_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.epp_login_id_seq OWNER TO fred;

--
-- Name: epp_login_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('epp_login_id_seq', 58, true);


--
-- Name: files; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE files (
    id integer NOT NULL,
    name character varying(300) NOT NULL,
    path character varying(300) NOT NULL,
    mimetype character varying(100) DEFAULT 'application/octet-stream'::character varying NOT NULL,
    crdate timestamp without time zone DEFAULT now() NOT NULL,
    filesize integer NOT NULL,
    filetype smallint
);


ALTER TABLE public.files OWNER TO fred;

--
-- Name: TABLE files; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE files IS 'table of files';


--
-- Name: COLUMN files.id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN files.id IS 'unique automatically generated identifier';


--
-- Name: COLUMN files.name; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN files.name IS 'file name';


--
-- Name: COLUMN files.path; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN files.path IS 'path to file';


--
-- Name: COLUMN files.mimetype; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN files.mimetype IS 'file mimetype';


--
-- Name: COLUMN files.crdate; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN files.crdate IS 'file creation timestamp';


--
-- Name: COLUMN files.filesize; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN files.filesize IS 'file size';


--
-- Name: COLUMN files.filetype; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN files.filetype IS 'file type from table enum_filetype';


--
-- Name: files_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE files_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.files_id_seq OWNER TO fred;

--
-- Name: files_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE files_id_seq OWNED BY files.id;


--
-- Name: files_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('files_id_seq', 7, true);


--
-- Name: filters; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE filters (
    id integer NOT NULL,
    type smallint NOT NULL,
    name character varying(255) NOT NULL,
    userid integer NOT NULL,
    groupid integer,
    data text NOT NULL
);


ALTER TABLE public.filters OWNER TO fred;

--
-- Name: TABLE filters; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE filters IS 'Table for saved object filters';


--
-- Name: COLUMN filters.id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN filters.id IS 'unique automatically generated identifier';


--
-- Name: COLUMN filters.type; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN filters.type IS 'filter object type -- 0 = filter on filter, 1 = filter on registrar, 2 = filter on object, 3 = filter on contact, 4 = filter on nsset, 5 = filter on domain, 6 = filter on action, 7 = filter on invoice, 8 = filter on authinfo, 9 = filter on mail';


--
-- Name: COLUMN filters.name; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN filters.name IS 'human readable filter name';


--
-- Name: COLUMN filters.userid; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN filters.userid IS 'filter creator';


--
-- Name: COLUMN filters.groupid; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN filters.groupid IS 'filter accessibility for group';


--
-- Name: COLUMN filters.data; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN filters.data IS 'filter definition';


--
-- Name: filters_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE filters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.filters_id_seq OWNER TO fred;

--
-- Name: filters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE filters_id_seq OWNED BY filters.id;


--
-- Name: filters_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('filters_id_seq', 1, false);


--
-- Name: genzone_domain_history; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE genzone_domain_history (
    id integer NOT NULL,
    domain_id integer,
    domain_hid integer,
    zone_id integer,
    status integer,
    inzone boolean NOT NULL,
    chdate timestamp without time zone DEFAULT now() NOT NULL,
    last boolean DEFAULT true NOT NULL
);


ALTER TABLE public.genzone_domain_history OWNER TO fred;

--
-- Name: TABLE genzone_domain_history; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE genzone_domain_history IS 'deprecated, unused, prepared for removal';


--
-- Name: genzone_domain_history_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE genzone_domain_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.genzone_domain_history_id_seq OWNER TO fred;

--
-- Name: genzone_domain_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE genzone_domain_history_id_seq OWNED BY genzone_domain_history.id;


--
-- Name: genzone_domain_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('genzone_domain_history_id_seq', 1, false);


--
-- Name: genzone_domain_status; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE genzone_domain_status (
    id integer NOT NULL,
    name character(20) NOT NULL
);


ALTER TABLE public.genzone_domain_status OWNER TO fred;

--
-- Name: TABLE genzone_domain_status; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE genzone_domain_status IS 'deprecated, unused, prepared for removal
List of status for domain zone generator classification

id - name
 1 - domain is in zone
 2 - domain is deleted
 3 - domain is without nsset
 4 - domain is expired
 5 - domain is not validated';


--
-- Name: history; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE history (
    id integer NOT NULL,
    valid_from timestamp without time zone DEFAULT now() NOT NULL,
    valid_to timestamp without time zone,
    next integer,
    request_id bigint
);


ALTER TABLE public.history OWNER TO fred;

--
-- Name: TABLE history; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE history IS 'Main evidence table with modified data, it join historic tables modified during same operation
create - in case of any change';


--
-- Name: COLUMN history.id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN history.id IS 'unique automatically generated identifier';


--
-- Name: COLUMN history.valid_from; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN history.valid_from IS 'date from which was this history created';


--
-- Name: COLUMN history.valid_to; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN history.valid_to IS 'date to which was history actual (NULL if it still is)';


--
-- Name: COLUMN history.next; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN history.next IS 'next history id';


--
-- Name: history_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE history_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.history_id_seq OWNER TO fred;

--
-- Name: history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE history_id_seq OWNED BY history.id;


--
-- Name: history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('history_id_seq', 58, true);


--
-- Name: host; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE host (
    id integer NOT NULL,
    nssetid integer,
    fqdn character varying(255) NOT NULL
);


ALTER TABLE public.host OWNER TO fred;

--
-- Name: TABLE host; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE host IS 'Records of relationship between nameserver and ip address';


--
-- Name: COLUMN host.id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN host.id IS 'unique automatically generatet identifier';


--
-- Name: COLUMN host.nssetid; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN host.nssetid IS 'in which nameserver group belong this record';


--
-- Name: COLUMN host.fqdn; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN host.fqdn IS 'fully qualified domain name that is in zone file as NS';


--
-- Name: host_history; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE host_history (
    historyid integer NOT NULL,
    id integer NOT NULL,
    nssetid integer,
    fqdn character varying(255) NOT NULL
);


ALTER TABLE public.host_history OWNER TO fred;

--
-- Name: TABLE host_history; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE host_history IS 'historic data from host table

creation - all entries from host table which exist for given nsset are copied here when nsset is altering';


--
-- Name: host_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE host_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.host_id_seq OWNER TO fred;

--
-- Name: host_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE host_id_seq OWNED BY host.id;


--
-- Name: host_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('host_id_seq', 20, true);


--
-- Name: host_ipaddr_map; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE host_ipaddr_map (
    id integer NOT NULL,
    hostid integer NOT NULL,
    nssetid integer NOT NULL,
    ipaddr inet NOT NULL
);


ALTER TABLE public.host_ipaddr_map OWNER TO fred;

--
-- Name: host_ipaddr_map_history; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE host_ipaddr_map_history (
    historyid integer NOT NULL,
    id integer NOT NULL,
    hostid integer NOT NULL,
    nssetid integer,
    ipaddr inet NOT NULL
);


ALTER TABLE public.host_ipaddr_map_history OWNER TO fred;

--
-- Name: host_ipaddr_map_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE host_ipaddr_map_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.host_ipaddr_map_id_seq OWNER TO fred;

--
-- Name: host_ipaddr_map_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE host_ipaddr_map_id_seq OWNED BY host_ipaddr_map.id;


--
-- Name: host_ipaddr_map_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('host_ipaddr_map_id_seq', 40, true);


--
-- Name: invoice; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE invoice (
    id integer NOT NULL,
    zone_id integer,
    crdate timestamp without time zone DEFAULT now() NOT NULL,
    taxdate date NOT NULL,
    prefix bigint NOT NULL,
    registrar_id integer NOT NULL,
    balance numeric(10,2) DEFAULT 0.0,
    operations_price numeric(10,2) DEFAULT 0.0,
    vat numeric NOT NULL,
    total numeric(10,2) DEFAULT 0.0 NOT NULL,
    totalvat numeric(10,2) DEFAULT 0.0 NOT NULL,
    invoice_prefix_id integer NOT NULL,
    file integer,
    filexml integer
);


ALTER TABLE public.invoice OWNER TO fred;

--
-- Name: TABLE invoice; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE invoice IS 'table of invoices';


--
-- Name: COLUMN invoice.id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice.id IS 'unique automatically generated identifier';


--
-- Name: COLUMN invoice.zone_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice.zone_id IS 'reference to zone';


--
-- Name: COLUMN invoice.crdate; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice.crdate IS 'date and time of invoice creation';


--
-- Name: COLUMN invoice.taxdate; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice.taxdate IS 'date of taxable fulfilment (when payment cames by advance FA)';


--
-- Name: COLUMN invoice.prefix; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice.prefix IS '9 placed number of invoice from invoice_prefix.prefix counted via TaxDate';


--
-- Name: COLUMN invoice.registrar_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice.registrar_id IS 'link to registrar';


--
-- Name: COLUMN invoice.balance; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice.balance IS '*advance invoice: balance from which operations are charged *account invoice: amount to be paid (0 in case there is no debt)';


--
-- Name: COLUMN invoice.operations_price; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice.operations_price IS 'sum of operations without tax';


--
-- Name: COLUMN invoice.vat; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice.vat IS 'VAT hight from account';


--
-- Name: COLUMN invoice.total; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice.total IS 'amount without tax';


--
-- Name: COLUMN invoice.totalvat; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice.totalvat IS 'tax paid';


--
-- Name: COLUMN invoice.invoice_prefix_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice.invoice_prefix_id IS 'invoice type - which year and type (accounting/advance) ';


--
-- Name: COLUMN invoice.file; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice.file IS 'link to generated PDF file, it can be NULL till file is generated';


--
-- Name: COLUMN invoice.filexml; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice.filexml IS 'link to generated XML file, it can be NULL till file is generated';


--
-- Name: invoice_credit_payment_map; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE invoice_credit_payment_map (
    ac_invoice_id integer NOT NULL,
    ad_invoice_id integer NOT NULL,
    credit numeric(10,2) DEFAULT 0.0 NOT NULL,
    balance numeric(10,2) DEFAULT 0.0 NOT NULL
);


ALTER TABLE public.invoice_credit_payment_map OWNER TO fred;

--
-- Name: COLUMN invoice_credit_payment_map.ac_invoice_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice_credit_payment_map.ac_invoice_id IS 'id of normal invoice';


--
-- Name: COLUMN invoice_credit_payment_map.ad_invoice_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice_credit_payment_map.ad_invoice_id IS 'id of advance invoice';


--
-- Name: COLUMN invoice_credit_payment_map.credit; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice_credit_payment_map.credit IS 'seized credit';


--
-- Name: COLUMN invoice_credit_payment_map.balance; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice_credit_payment_map.balance IS 'actual tax balance advance invoice';


--
-- Name: invoice_generation; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE invoice_generation (
    id integer NOT NULL,
    fromdate date NOT NULL,
    todate date NOT NULL,
    registrar_id integer NOT NULL,
    zone_id integer,
    invoice_id integer
);


ALTER TABLE public.invoice_generation OWNER TO fred;

--
-- Name: COLUMN invoice_generation.id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice_generation.id IS 'unique automatically generated identifier';


--
-- Name: COLUMN invoice_generation.invoice_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice_generation.invoice_id IS 'id of normal invoice';


--
-- Name: invoice_generation_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE invoice_generation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.invoice_generation_id_seq OWNER TO fred;

--
-- Name: invoice_generation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE invoice_generation_id_seq OWNED BY invoice_generation.id;


--
-- Name: invoice_generation_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('invoice_generation_id_seq', 1, false);


--
-- Name: invoice_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE invoice_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.invoice_id_seq OWNER TO fred;

--
-- Name: invoice_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE invoice_id_seq OWNED BY invoice.id;


--
-- Name: invoice_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('invoice_id_seq', 12, true);


--
-- Name: invoice_mails; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE invoice_mails (
    id integer NOT NULL,
    invoiceid integer,
    genid integer,
    mailid integer NOT NULL
);


ALTER TABLE public.invoice_mails OWNER TO fred;

--
-- Name: COLUMN invoice_mails.invoiceid; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice_mails.invoiceid IS 'link to invoices';


--
-- Name: COLUMN invoice_mails.mailid; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice_mails.mailid IS 'e-mail which contains this invoice';


--
-- Name: invoice_mails_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE invoice_mails_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.invoice_mails_id_seq OWNER TO fred;

--
-- Name: invoice_mails_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE invoice_mails_id_seq OWNED BY invoice_mails.id;


--
-- Name: invoice_mails_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('invoice_mails_id_seq', 1, false);


--
-- Name: invoice_number_prefix; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE invoice_number_prefix (
    id integer NOT NULL,
    prefix integer NOT NULL,
    zone_id bigint NOT NULL,
    invoice_type_id bigint NOT NULL
);


ALTER TABLE public.invoice_number_prefix OWNER TO fred;

--
-- Name: TABLE invoice_number_prefix; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE invoice_number_prefix IS 'prefixes to invoice number, next year prefixes are generated according to records in this table';


--
-- Name: COLUMN invoice_number_prefix.prefix; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice_number_prefix.prefix IS 'two-digit number';


--
-- Name: invoice_number_prefix_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE invoice_number_prefix_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.invoice_number_prefix_id_seq OWNER TO fred;

--
-- Name: invoice_number_prefix_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE invoice_number_prefix_id_seq OWNED BY invoice_number_prefix.id;


--
-- Name: invoice_number_prefix_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('invoice_number_prefix_id_seq', 4, true);


--
-- Name: invoice_operation; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE invoice_operation (
    id integer NOT NULL,
    ac_invoice_id integer,
    crdate timestamp without time zone DEFAULT now() NOT NULL,
    object_id integer,
    zone_id integer,
    registrar_id integer NOT NULL,
    operation_id integer NOT NULL,
    date_from date,
    date_to date,
    quantity integer DEFAULT 0,
    registrar_credit_transaction_id bigint NOT NULL
);


ALTER TABLE public.invoice_operation OWNER TO fred;

--
-- Name: COLUMN invoice_operation.id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice_operation.id IS 'unique automatically generated identifier';


--
-- Name: COLUMN invoice_operation.ac_invoice_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice_operation.ac_invoice_id IS 'id of invoice for which is item counted';


--
-- Name: COLUMN invoice_operation.crdate; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice_operation.crdate IS 'billing date and time';


--
-- Name: COLUMN invoice_operation.zone_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice_operation.zone_id IS 'link to zone';


--
-- Name: COLUMN invoice_operation.registrar_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice_operation.registrar_id IS 'link to registrar';


--
-- Name: COLUMN invoice_operation.operation_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice_operation.operation_id IS 'operation type of registration or renew';


--
-- Name: COLUMN invoice_operation.date_to; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice_operation.date_to IS 'expiration date only for RENEW';


--
-- Name: COLUMN invoice_operation.quantity; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice_operation.quantity IS 'number of operations or number of months for renew';


--
-- Name: invoice_operation_charge_map; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE invoice_operation_charge_map (
    invoice_operation_id integer NOT NULL,
    invoice_id integer NOT NULL,
    price numeric(10,2) DEFAULT 0 NOT NULL
);


ALTER TABLE public.invoice_operation_charge_map OWNER TO fred;

--
-- Name: COLUMN invoice_operation_charge_map.invoice_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice_operation_charge_map.invoice_id IS 'id of advanced invoice';


--
-- Name: COLUMN invoice_operation_charge_map.price; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice_operation_charge_map.price IS 'operation cost';


--
-- Name: invoice_operation_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE invoice_operation_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.invoice_operation_id_seq OWNER TO fred;

--
-- Name: invoice_operation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE invoice_operation_id_seq OWNED BY invoice_operation.id;


--
-- Name: invoice_operation_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('invoice_operation_id_seq', 62, true);


--
-- Name: invoice_prefix; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE invoice_prefix (
    id integer NOT NULL,
    zone_id integer,
    typ integer,
    year numeric NOT NULL,
    prefix bigint
);


ALTER TABLE public.invoice_prefix OWNER TO fred;

--
-- Name: COLUMN invoice_prefix.zone_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice_prefix.zone_id IS 'reference to zone';


--
-- Name: COLUMN invoice_prefix.typ; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice_prefix.typ IS 'invoice type (0-advanced, 1-normal)';


--
-- Name: COLUMN invoice_prefix.year; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice_prefix.year IS 'for which year';


--
-- Name: COLUMN invoice_prefix.prefix; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN invoice_prefix.prefix IS 'counter with prefix of number of invoice';


--
-- Name: invoice_prefix_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE invoice_prefix_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.invoice_prefix_id_seq OWNER TO fred;

--
-- Name: invoice_prefix_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE invoice_prefix_id_seq OWNED BY invoice_prefix.id;


--
-- Name: invoice_prefix_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('invoice_prefix_id_seq', 28, true);


--
-- Name: invoice_registrar_credit_transaction_map; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE invoice_registrar_credit_transaction_map (
    id bigint NOT NULL,
    invoice_id bigint NOT NULL,
    registrar_credit_transaction_id bigint NOT NULL
);


ALTER TABLE public.invoice_registrar_credit_transaction_map OWNER TO fred;

--
-- Name: TABLE invoice_registrar_credit_transaction_map; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE invoice_registrar_credit_transaction_map IS 'positive credit item from payment assigned to deposit or account invoice';


--
-- Name: invoice_registrar_credit_transaction_map_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE invoice_registrar_credit_transaction_map_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.invoice_registrar_credit_transaction_map_id_seq OWNER TO fred;

--
-- Name: invoice_registrar_credit_transaction_map_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE invoice_registrar_credit_transaction_map_id_seq OWNED BY invoice_registrar_credit_transaction_map.id;


--
-- Name: invoice_registrar_credit_transaction_map_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('invoice_registrar_credit_transaction_map_id_seq', 12, true);


--
-- Name: invoice_type; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE invoice_type (
    id integer NOT NULL,
    name text
);


ALTER TABLE public.invoice_type OWNER TO fred;

--
-- Name: TABLE invoice_type; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE invoice_type IS 'invoice types list';


--
-- Name: invoice_type_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE invoice_type_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.invoice_type_id_seq OWNER TO fred;

--
-- Name: invoice_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE invoice_type_id_seq OWNED BY invoice_type.id;


--
-- Name: invoice_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('invoice_type_id_seq', 1, true);


--
-- Name: keyset; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE keyset (
    id integer NOT NULL
);


ALTER TABLE public.keyset OWNER TO fred;

--
-- Name: TABLE keyset; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE keyset IS 'Evidence of Keysets';


--
-- Name: COLUMN keyset.id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN keyset.id IS 'reference into object table';


--
-- Name: keyset_contact_map_history; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE keyset_contact_map_history (
    historyid integer NOT NULL,
    keysetid integer NOT NULL,
    contactid integer NOT NULL
);


ALTER TABLE public.keyset_contact_map_history OWNER TO fred;

--
-- Name: keyset_history; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE keyset_history (
    historyid integer NOT NULL,
    id integer
);


ALTER TABLE public.keyset_history OWNER TO fred;

--
-- Name: TABLE keyset_history; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE keyset_history IS 'historic data from Keyset table';


--
-- Name: keyset_states; Type: VIEW; Schema: public; Owner: fred
--

CREATE VIEW keyset_states AS
    SELECT o.id AS object_id, o.historyid AS object_hid, ((COALESCE(osr.states, '{}'::integer[]) || CASE WHEN (NOT (d.keyset IS NULL)) THEN ARRAY[16] ELSE '{}'::integer[] END) || CASE WHEN (((d.keyset IS NULL) AND date_month_test(GREATEST((COALESCE(l.last_linked, o.crdate))::date, (COALESCE(ob.update, o.crdate))::date), ep_mn.val, ep_tm.val, ep_tz.val)) AND (NOT (1 = ANY (COALESCE(osr.states, '{}'::integer[]))))) THEN ARRAY[17] ELSE '{}'::integer[] END) AS states FROM (((((((object ob JOIN object_registry o ON (((ob.id = o.id) AND (o.type = 4)))) JOIN enum_parameters ep_tm ON ((ep_tm.id = 9))) JOIN enum_parameters ep_tz ON ((ep_tz.id = 10))) JOIN enum_parameters ep_mn ON ((ep_mn.id = 11))) LEFT JOIN (SELECT DISTINCT domain.keyset FROM domain ORDER BY domain.keyset) d ON ((d.keyset = o.id))) LEFT JOIN (SELECT object_state.object_id, max(object_state.valid_to) AS last_linked FROM object_state WHERE (object_state.state_id = 16) GROUP BY object_state.object_id) l ON ((o.id = l.object_id))) LEFT JOIN object_state_request_now osr ON ((o.id = osr.object_id)));


ALTER TABLE public.keyset_states OWNER TO fred;

--
-- Name: letter_archive; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE letter_archive (
    id integer NOT NULL,
    file_id integer,
    batch_id character varying(64),
    postal_address_name character varying(1024),
    postal_address_organization character varying(1024),
    postal_address_street1 character varying(1024),
    postal_address_street2 character varying(1024),
    postal_address_street3 character varying(1024),
    postal_address_city character varying(1024),
    postal_address_stateorprovince character varying(1024),
    postal_address_postalcode character varying(32),
    postal_address_country character varying(1024),
    postal_address_id integer
);


ALTER TABLE public.letter_archive OWNER TO fred;

--
-- Name: TABLE letter_archive; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE letter_archive IS 'letters sent electronically as PDF documents to postal service, address is included in the document';


--
-- Name: COLUMN letter_archive.file_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN letter_archive.file_id IS 'file with pdf about notification (null for old)';


--
-- Name: COLUMN letter_archive.batch_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN letter_archive.batch_id IS 'postservis batch id - multiple letters are bundled into batches';


--
-- Name: mail_archive; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE mail_archive (
    id integer NOT NULL,
    mailtype integer,
    crdate timestamp without time zone DEFAULT now() NOT NULL,
    moddate timestamp without time zone,
    status integer,
    message text NOT NULL,
    attempt smallint DEFAULT 0 NOT NULL,
    response text
);


ALTER TABLE public.mail_archive OWNER TO fred;

--
-- Name: TABLE mail_archive; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE mail_archive IS 'Here are stored emails which are going to be sent and email which have
already been sent (they differ in status value).';


--
-- Name: COLUMN mail_archive.mailtype; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN mail_archive.mailtype IS 'email type';


--
-- Name: COLUMN mail_archive.crdate; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN mail_archive.crdate IS 'date and time of insertion in table';


--
-- Name: COLUMN mail_archive.moddate; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN mail_archive.moddate IS 'date and time of sending (event unsuccesfull)';


--
-- Name: COLUMN mail_archive.status; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN mail_archive.status IS 'status value has following meanings:
 0 - the email was successfully sent
 1 - the email is ready to be sent
 x - the email wait for manual confirmation which should change status value to 0
     when the email is desired to be sent. x represent any value different from
     0 and 1 (convention is number 2)';


--
-- Name: COLUMN mail_archive.message; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN mail_archive.message IS 'text of email which is asssumed to be notificaion about undelivered';


--
-- Name: COLUMN mail_archive.attempt; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN mail_archive.attempt IS 'failed attempt to send email message to be sent including headers
(except date and msgid header), without non-templated attachments';


--
-- Name: mail_archive_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE mail_archive_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.mail_archive_id_seq OWNER TO fred;

--
-- Name: mail_archive_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE mail_archive_id_seq OWNED BY mail_archive.id;


--
-- Name: mail_archive_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('mail_archive_id_seq', 58, true);


--
-- Name: mail_attachments; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE mail_attachments (
    id integer NOT NULL,
    mailid integer,
    attachid integer
);


ALTER TABLE public.mail_attachments OWNER TO fred;

--
-- Name: TABLE mail_attachments; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE mail_attachments IS 'list of attachment ids bound to email in mail_archive';


--
-- Name: COLUMN mail_attachments.mailid; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN mail_attachments.mailid IS 'id of email in archive';


--
-- Name: COLUMN mail_attachments.attachid; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN mail_attachments.attachid IS 'attachment id';


--
-- Name: mail_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE mail_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.mail_attachments_id_seq OWNER TO fred;

--
-- Name: mail_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE mail_attachments_id_seq OWNED BY mail_attachments.id;


--
-- Name: mail_attachments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('mail_attachments_id_seq', 1, false);


--
-- Name: mail_defaults; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE mail_defaults (
    id integer NOT NULL,
    name character varying(300) NOT NULL,
    value text NOT NULL
);


ALTER TABLE public.mail_defaults OWNER TO fred;

--
-- Name: TABLE mail_defaults; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE mail_defaults IS 'Defaults used in templates which change rarely.
Default names must be prefixed with ''defaults'' namespace when used in template';


--
-- Name: COLUMN mail_defaults.name; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN mail_defaults.name IS 'key of default';


--
-- Name: COLUMN mail_defaults.value; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN mail_defaults.value IS 'value of default';


--
-- Name: mail_defaults_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE mail_defaults_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.mail_defaults_id_seq OWNER TO fred;

--
-- Name: mail_defaults_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE mail_defaults_id_seq OWNED BY mail_defaults.id;


--
-- Name: mail_defaults_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('mail_defaults_id_seq', 9, true);


--
-- Name: mail_footer; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE mail_footer (
    id integer NOT NULL,
    footer text NOT NULL
);


ALTER TABLE public.mail_footer OWNER TO fred;

--
-- Name: TABLE mail_footer; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE mail_footer IS 'Mail footer is defided in this table and not in templates in order to reduce templates size';


--
-- Name: mail_handles; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE mail_handles (
    id integer NOT NULL,
    mailid integer,
    associd character varying(255)
);


ALTER TABLE public.mail_handles OWNER TO fred;

--
-- Name: TABLE mail_handles; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE mail_handles IS 'handles associated with email in mail_archive';


--
-- Name: COLUMN mail_handles.mailid; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN mail_handles.mailid IS 'id of email in archive';


--
-- Name: COLUMN mail_handles.associd; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN mail_handles.associd IS 'handle of associated object';


--
-- Name: mail_handles_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE mail_handles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.mail_handles_id_seq OWNER TO fred;

--
-- Name: mail_handles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE mail_handles_id_seq OWNED BY mail_handles.id;


--
-- Name: mail_handles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('mail_handles_id_seq', 1, false);


--
-- Name: mail_header_defaults; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE mail_header_defaults (
    id integer NOT NULL,
    h_from character varying(300),
    h_replyto character varying(300),
    h_errorsto character varying(300),
    h_organization character varying(300),
    h_contentencoding character varying(300),
    h_messageidserver character varying(300)
);


ALTER TABLE public.mail_header_defaults OWNER TO fred;

--
-- Name: TABLE mail_header_defaults; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE mail_header_defaults IS 'Some header defaults which are likely not a subject to change are specified in database and used in absence';


--
-- Name: COLUMN mail_header_defaults.h_from; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN mail_header_defaults.h_from IS '''From:'' header';


--
-- Name: COLUMN mail_header_defaults.h_replyto; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN mail_header_defaults.h_replyto IS '''Reply-to:'' header';


--
-- Name: COLUMN mail_header_defaults.h_errorsto; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN mail_header_defaults.h_errorsto IS '''Errors-to:'' header';


--
-- Name: COLUMN mail_header_defaults.h_organization; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN mail_header_defaults.h_organization IS '''Organization:'' header';


--
-- Name: COLUMN mail_header_defaults.h_contentencoding; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN mail_header_defaults.h_contentencoding IS '''Content-encoding:'' header';


--
-- Name: COLUMN mail_header_defaults.h_messageidserver; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN mail_header_defaults.h_messageidserver IS 'Message id cannot be overriden by client, in db is stored only part after ''@'' character';


--
-- Name: mail_header_defaults_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE mail_header_defaults_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.mail_header_defaults_id_seq OWNER TO fred;

--
-- Name: mail_header_defaults_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE mail_header_defaults_id_seq OWNED BY mail_header_defaults.id;


--
-- Name: mail_header_defaults_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('mail_header_defaults_id_seq', 1, true);


--
-- Name: mail_templates; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE mail_templates (
    id integer NOT NULL,
    contenttype character varying(100) NOT NULL,
    template text NOT NULL,
    footer integer
);


ALTER TABLE public.mail_templates OWNER TO fred;

--
-- Name: TABLE mail_templates; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE mail_templates IS 'Here are stored email templates which represent one text attachment of email message';


--
-- Name: COLUMN mail_templates.contenttype; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN mail_templates.contenttype IS 'subtype of content type text';


--
-- Name: COLUMN mail_templates.template; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN mail_templates.template IS 'clearsilver template';


--
-- Name: COLUMN mail_templates.footer; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN mail_templates.footer IS 'should footer be concatenated with template?';


--
-- Name: mail_type; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE mail_type (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    subject character varying(550) NOT NULL
);


ALTER TABLE public.mail_type OWNER TO fred;

--
-- Name: TABLE mail_type; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE mail_type IS 'Type of email gathers templates from which email is composed';


--
-- Name: COLUMN mail_type.name; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN mail_type.name IS 'name of type';


--
-- Name: COLUMN mail_type.subject; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN mail_type.subject IS 'template of email subject';


--
-- Name: mail_type_template_map; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE mail_type_template_map (
    typeid integer NOT NULL,
    templateid integer NOT NULL
);


ALTER TABLE public.mail_type_template_map OWNER TO fred;

--
-- Name: mail_vcard; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE mail_vcard (
    vcard text NOT NULL,
    id integer NOT NULL
);


ALTER TABLE public.mail_vcard OWNER TO fred;

--
-- Name: TABLE mail_vcard; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE mail_vcard IS 'vcard is attached to every email message';


--
-- Name: mail_vcard_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE mail_vcard_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.mail_vcard_id_seq OWNER TO fred;

--
-- Name: mail_vcard_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE mail_vcard_id_seq OWNED BY mail_vcard.id;


--
-- Name: mail_vcard_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('mail_vcard_id_seq', 1, true);


--
-- Name: message; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE message (
    id integer NOT NULL,
    clid integer NOT NULL,
    crdate timestamp without time zone DEFAULT now() NOT NULL,
    exdate timestamp without time zone,
    seen boolean DEFAULT false NOT NULL,
    msgtype integer
);


ALTER TABLE public.message OWNER TO fred;

--
-- Name: TABLE message; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE message IS 'Evidence of messages for registrars, which can be picked up by epp poll funcion';


--
-- Name: message_archive; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE message_archive (
    id integer NOT NULL,
    crdate timestamp without time zone DEFAULT now() NOT NULL,
    moddate timestamp without time zone,
    attempt smallint DEFAULT 0 NOT NULL,
    status_id integer,
    comm_type_id integer,
    message_type_id integer
);


ALTER TABLE public.message_archive OWNER TO fred;

--
-- Name: COLUMN message_archive.crdate; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN message_archive.crdate IS 'date and time of insertion in table';


--
-- Name: COLUMN message_archive.moddate; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN message_archive.moddate IS 'date and time of sending (event unsuccesfull)';


--
-- Name: COLUMN message_archive.status_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN message_archive.status_id IS 'status';


--
-- Name: message_archive_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE message_archive_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.message_archive_id_seq OWNER TO fred;

--
-- Name: message_archive_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE message_archive_id_seq OWNED BY message_archive.id;


--
-- Name: message_archive_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('message_archive_id_seq', 1, false);


--
-- Name: message_contact_history_map; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE message_contact_history_map (
    id integer NOT NULL,
    contact_object_registry_id integer,
    contact_history_historyid integer,
    message_archive_id integer
);


ALTER TABLE public.message_contact_history_map OWNER TO fred;

--
-- Name: message_contact_history_map_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE message_contact_history_map_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.message_contact_history_map_id_seq OWNER TO fred;

--
-- Name: message_contact_history_map_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE message_contact_history_map_id_seq OWNED BY message_contact_history_map.id;


--
-- Name: message_contact_history_map_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('message_contact_history_map_id_seq', 1, false);


--
-- Name: message_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE message_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.message_id_seq OWNER TO fred;

--
-- Name: message_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE message_id_seq OWNED BY message.id;


--
-- Name: message_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('message_id_seq', 1, false);


--
-- Name: message_type; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE message_type (
    id integer NOT NULL,
    type character varying(64)
);


ALTER TABLE public.message_type OWNER TO fred;

--
-- Name: TABLE message_type; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE message_type IS 'type of message with respect to subject of message';


--
-- Name: message_type_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE message_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.message_type_id_seq OWNER TO fred;

--
-- Name: message_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE message_type_id_seq OWNED BY message_type.id;


--
-- Name: message_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('message_type_id_seq', 1, false);


--
-- Name: messagetype; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE messagetype (
    id integer NOT NULL,
    name character varying(30) NOT NULL
);


ALTER TABLE public.messagetype OWNER TO fred;

--
-- Name: TABLE messagetype; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE messagetype IS 'table with message number codes and its names

id - name
01 - credit
02 - techcheck
03 - transfer_contact
04 - transfer_nsset
05 - transfer_domain
06 - delete_contact
07 - delete_nsset
08 - delete_domain
09 - imp_expiration
10 - expiration
11 - imp_validation
12 - validation
13 - outzone';


--
-- Name: notify_letters; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE notify_letters (
    state_id integer NOT NULL,
    letter_id integer
);


ALTER TABLE public.notify_letters OWNER TO fred;

--
-- Name: TABLE notify_letters; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE notify_letters IS 'notifications about deleteWarning state sent as PDF letters';


--
-- Name: COLUMN notify_letters.state_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN notify_letters.state_id IS 'which statechange triggered notification';


--
-- Name: COLUMN notify_letters.letter_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN notify_letters.letter_id IS 'which message notifies the state change';


--
-- Name: notify_request; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE notify_request (
    request_id bigint NOT NULL,
    message_id integer NOT NULL
);


ALTER TABLE public.notify_request OWNER TO fred;

--
-- Name: notify_statechange; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE notify_statechange (
    state_id integer NOT NULL,
    type integer NOT NULL,
    mail_id integer
);


ALTER TABLE public.notify_statechange OWNER TO fred;

--
-- Name: TABLE notify_statechange; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE notify_statechange IS 'store information about successfull notification';


--
-- Name: COLUMN notify_statechange.state_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN notify_statechange.state_id IS 'which statechnage triggered notification';


--
-- Name: COLUMN notify_statechange.type; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN notify_statechange.type IS 'what notification was done';


--
-- Name: COLUMN notify_statechange.mail_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN notify_statechange.mail_id IS 'email with result of notification (null if contact have no email)';


--
-- Name: notify_statechange_map; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE notify_statechange_map (
    id integer NOT NULL,
    state_id integer NOT NULL,
    obj_type integer NOT NULL,
    mail_type_id integer NOT NULL,
    emails integer
);


ALTER TABLE public.notify_statechange_map OWNER TO fred;

--
-- Name: TABLE notify_statechange_map; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE notify_statechange_map IS 'Notification processing rules - direct notifier what mails need to be send
and whom upon object state change';


--
-- Name: COLUMN notify_statechange_map.state_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN notify_statechange_map.state_id IS 'id of state to be notified by email';


--
-- Name: COLUMN notify_statechange_map.obj_type; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN notify_statechange_map.obj_type IS 'type of object to be notified (1..contact, 2..nsset, 3..domain, 4..keyset)';


--
-- Name: COLUMN notify_statechange_map.mail_type_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN notify_statechange_map.mail_type_id IS 'type of mail to be send';


--
-- Name: COLUMN notify_statechange_map.emails; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN notify_statechange_map.emails IS 'type of contact group to be notified by email (1..admins, 2..techs)';


--
-- Name: nsset; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE nsset (
    id integer NOT NULL,
    checklevel smallint DEFAULT 0
);


ALTER TABLE public.nsset OWNER TO fred;

--
-- Name: nsset_contact_map_history; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE nsset_contact_map_history (
    historyid integer NOT NULL,
    nssetid integer NOT NULL,
    contactid integer NOT NULL
);


ALTER TABLE public.nsset_contact_map_history OWNER TO fred;

--
-- Name: TABLE nsset_contact_map_history; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE nsset_contact_map_history IS 'Historic data from nsset_contact_map table

creation - all contact links which are linked to changed nsset are copied here';


--
-- Name: nsset_history; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE nsset_history (
    historyid integer NOT NULL,
    id integer,
    checklevel smallint DEFAULT 0
);


ALTER TABLE public.nsset_history OWNER TO fred;

--
-- Name: TABLE nsset_history; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE nsset_history IS 'Historic data from domain nsset

creation - in case of any change in nsset table, including changes in bindings to other tables';


--
-- Name: nsset_states; Type: VIEW; Schema: public; Owner: fred
--

CREATE VIEW nsset_states AS
    SELECT o.id AS object_id, o.historyid AS object_hid, ((COALESCE(osr.states, '{}'::integer[]) || CASE WHEN (NOT (d.nsset IS NULL)) THEN ARRAY[16] ELSE '{}'::integer[] END) || CASE WHEN (((d.nsset IS NULL) AND date_month_test(GREATEST((COALESCE(l.last_linked, o.crdate))::date, (COALESCE(ob.update, o.crdate))::date), ep_mn.val, ep_tm.val, ep_tz.val)) AND (NOT (1 = ANY (COALESCE(osr.states, '{}'::integer[]))))) THEN ARRAY[17] ELSE '{}'::integer[] END) AS states FROM (((((((object ob JOIN object_registry o ON (((ob.id = o.id) AND (o.type = 2)))) JOIN enum_parameters ep_tm ON ((ep_tm.id = 9))) JOIN enum_parameters ep_tz ON ((ep_tz.id = 10))) JOIN enum_parameters ep_mn ON ((ep_mn.id = 11))) LEFT JOIN (SELECT DISTINCT domain.nsset FROM domain ORDER BY domain.nsset) d ON ((d.nsset = o.id))) LEFT JOIN (SELECT object_state.object_id, max(object_state.valid_to) AS last_linked FROM object_state WHERE (object_state.state_id = 16) GROUP BY object_state.object_id) l ON ((o.id = l.object_id))) LEFT JOIN object_state_request_now osr ON ((o.id = osr.object_id)));


ALTER TABLE public.nsset_states OWNER TO fred;

--
-- Name: object_history; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE object_history (
    historyid integer NOT NULL,
    id integer,
    clid integer NOT NULL,
    upid integer,
    trdate timestamp without time zone,
    update timestamp without time zone,
    authinfopw character varying(300)
);


ALTER TABLE public.object_history OWNER TO fred;

--
-- Name: object_registry_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE object_registry_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.object_registry_id_seq OWNER TO fred;

--
-- Name: object_registry_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE object_registry_id_seq OWNED BY object_registry.id;


--
-- Name: object_registry_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('object_registry_id_seq', 58, true);


--
-- Name: object_state_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE object_state_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.object_state_id_seq OWNER TO fred;

--
-- Name: object_state_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE object_state_id_seq OWNED BY object_state.id;


--
-- Name: object_state_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('object_state_id_seq', 186, true);


--
-- Name: object_state_now; Type: VIEW; Schema: public; Owner: fred
--

CREATE VIEW object_state_now AS
    SELECT object_state.object_id, array_accum(object_state.state_id) AS states FROM object_state WHERE (object_state.valid_to IS NULL) GROUP BY object_state.object_id;


ALTER TABLE public.object_state_now OWNER TO fred;

--
-- Name: object_state_request_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE object_state_request_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.object_state_request_id_seq OWNER TO fred;

--
-- Name: object_state_request_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE object_state_request_id_seq OWNED BY object_state_request.id;


--
-- Name: object_state_request_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('object_state_request_id_seq', 1, true);


--
-- Name: object_state_request_lock; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE object_state_request_lock (
    id bigint NOT NULL,
    state_id integer NOT NULL,
    object_id integer NOT NULL
);


ALTER TABLE public.object_state_request_lock OWNER TO fred;

--
-- Name: object_state_request_lock_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE object_state_request_lock_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.object_state_request_lock_id_seq OWNER TO fred;

--
-- Name: object_state_request_lock_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE object_state_request_lock_id_seq OWNED BY object_state_request_lock.id;


--
-- Name: object_state_request_lock_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('object_state_request_lock_id_seq', 1, true);


--
-- Name: poll_credit; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE poll_credit (
    msgid integer NOT NULL,
    zone integer,
    credlimit numeric(10,2) NOT NULL,
    credit numeric(10,2) NOT NULL
);


ALTER TABLE public.poll_credit OWNER TO fred;

--
-- Name: poll_credit_zone_limit; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE poll_credit_zone_limit (
    zone integer NOT NULL,
    credlimit numeric(10,2) NOT NULL
);


ALTER TABLE public.poll_credit_zone_limit OWNER TO fred;

--
-- Name: poll_eppaction; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE poll_eppaction (
    msgid integer NOT NULL,
    objid integer
);


ALTER TABLE public.poll_eppaction OWNER TO fred;

--
-- Name: poll_request_fee; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE poll_request_fee (
    msgid integer NOT NULL,
    period_from timestamp without time zone NOT NULL,
    period_to timestamp without time zone NOT NULL,
    total_free_count bigint NOT NULL,
    used_count bigint NOT NULL,
    price numeric(10,2) NOT NULL
);


ALTER TABLE public.poll_request_fee OWNER TO fred;

--
-- Name: poll_statechange; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE poll_statechange (
    msgid integer NOT NULL,
    stateid integer
);


ALTER TABLE public.poll_statechange OWNER TO fred;

--
-- Name: poll_techcheck; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE poll_techcheck (
    msgid integer NOT NULL,
    cnid integer
);


ALTER TABLE public.poll_techcheck OWNER TO fred;

--
-- Name: price_list; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE price_list (
    id integer NOT NULL,
    zone_id integer NOT NULL,
    operation_id integer NOT NULL,
    valid_from timestamp without time zone NOT NULL,
    valid_to timestamp without time zone,
    price numeric(10,2) DEFAULT 0 NOT NULL,
    quantity integer DEFAULT 12,
    enable_postpaid_operation boolean DEFAULT false
);


ALTER TABLE public.price_list OWNER TO fred;

--
-- Name: TABLE price_list; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE price_list IS 'list of operation prices';


--
-- Name: COLUMN price_list.id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN price_list.id IS 'unique automatically generated identifier';


--
-- Name: COLUMN price_list.zone_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN price_list.zone_id IS 'link to zone, for which is price list valid if it is domain (if it is not domain then it is NULL)';


--
-- Name: COLUMN price_list.operation_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN price_list.operation_id IS 'for which action is price connected';


--
-- Name: COLUMN price_list.valid_from; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN price_list.valid_from IS 'from when is record valid';


--
-- Name: COLUMN price_list.valid_to; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN price_list.valid_to IS 'till when is record valid, if it is NULL then valid is unlimited';


--
-- Name: COLUMN price_list.price; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN price_list.price IS 'cost of operation (for one year-12 months)';


--
-- Name: COLUMN price_list.quantity; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN price_list.quantity IS 'quantity of operation or period (in months) of payment, null if it is not periodic';


--
-- Name: COLUMN price_list.enable_postpaid_operation; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN price_list.enable_postpaid_operation IS 'true if operation of this specific type can be executed when credit is not sufficient and create debt';


--
-- Name: price_list_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE price_list_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.price_list_id_seq OWNER TO fred;

--
-- Name: price_list_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE price_list_id_seq OWNED BY price_list.id;


--
-- Name: price_list_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('price_list_id_seq', 8, true);


--
-- Name: price_vat; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE price_vat (
    id integer NOT NULL,
    valid_to timestamp without time zone,
    koef numeric,
    vat numeric DEFAULT 19
);


ALTER TABLE public.price_vat OWNER TO fred;

--
-- Name: TABLE price_vat; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE price_vat IS 'Table of VAT validity (in case that VAT is changing in the future. Stores coefficient for VAT recount)';


--
-- Name: COLUMN price_vat.id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN price_vat.id IS 'unique automatically generated identifier';


--
-- Name: COLUMN price_vat.valid_to; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN price_vat.valid_to IS 'date of VAT change realization';


--
-- Name: COLUMN price_vat.koef; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN price_vat.koef IS 'coefficient high for VAT recount';


--
-- Name: COLUMN price_vat.vat; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN price_vat.vat IS 'VAT high';


--
-- Name: price_vat_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE price_vat_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.price_vat_id_seq OWNER TO fred;

--
-- Name: price_vat_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE price_vat_id_seq OWNED BY price_vat.id;


--
-- Name: price_vat_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('price_vat_id_seq', 3, true);


--
-- Name: public_request; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE public_request (
    id integer NOT NULL,
    request_type smallint NOT NULL,
    create_time timestamp without time zone DEFAULT now() NOT NULL,
    status smallint NOT NULL,
    resolve_time timestamp without time zone,
    reason character varying(512),
    email_to_answer character varying(255),
    answer_email_id integer,
    registrar_id integer,
    create_request_id bigint,
    resolve_request_id bigint
);


ALTER TABLE public.public_request OWNER TO fred;

--
-- Name: TABLE public_request; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE public_request IS 'table of general requests give in by public users';


--
-- Name: COLUMN public_request.request_type; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN public_request.request_type IS 'code of request';


--
-- Name: COLUMN public_request.create_time; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN public_request.create_time IS 'request creation time';


--
-- Name: COLUMN public_request.status; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN public_request.status IS 'code of request actual status';


--
-- Name: COLUMN public_request.resolve_time; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN public_request.resolve_time IS 'time when request was processed (closed)';


--
-- Name: COLUMN public_request.reason; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN public_request.reason IS 'reason';


--
-- Name: COLUMN public_request.email_to_answer; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN public_request.email_to_answer IS 'manual entered email by user for sending answer (if it is automatic from object contact it is NULL)';


--
-- Name: COLUMN public_request.answer_email_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN public_request.answer_email_id IS 'reference to mail which was send after request was processed';


--
-- Name: COLUMN public_request.registrar_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN public_request.registrar_id IS 'reference to registrar when request is submitted via EPP protocol (otherwise NULL)';


--
-- Name: public_request_auth; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE public_request_auth (
    id integer NOT NULL,
    identification character varying(32) NOT NULL,
    password character varying(64) NOT NULL
);


ALTER TABLE public.public_request_auth OWNER TO fred;

--
-- Name: public_request_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE public_request_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.public_request_id_seq OWNER TO fred;

--
-- Name: public_request_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE public_request_id_seq OWNED BY public_request.id;


--
-- Name: public_request_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('public_request_id_seq', 1, false);


--
-- Name: public_request_lock; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE public_request_lock (
    id bigint NOT NULL,
    request_type smallint NOT NULL,
    object_id integer NOT NULL
);


ALTER TABLE public.public_request_lock OWNER TO fred;

--
-- Name: public_request_lock_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE public_request_lock_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.public_request_lock_id_seq OWNER TO fred;

--
-- Name: public_request_lock_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE public_request_lock_id_seq OWNED BY public_request_lock.id;


--
-- Name: public_request_lock_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('public_request_lock_id_seq', 1, false);


--
-- Name: public_request_messages_map; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE public_request_messages_map (
    id integer NOT NULL,
    public_request_id integer,
    message_archive_id integer,
    mail_archive_id integer
);


ALTER TABLE public.public_request_messages_map OWNER TO fred;

--
-- Name: public_request_messages_map_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE public_request_messages_map_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.public_request_messages_map_id_seq OWNER TO fred;

--
-- Name: public_request_messages_map_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE public_request_messages_map_id_seq OWNED BY public_request_messages_map.id;


--
-- Name: public_request_messages_map_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('public_request_messages_map_id_seq', 1, false);


--
-- Name: public_request_objects_map; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE public_request_objects_map (
    request_id integer NOT NULL,
    object_id integer
);


ALTER TABLE public.public_request_objects_map OWNER TO fred;

--
-- Name: TABLE public_request_objects_map; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE public_request_objects_map IS 'table with objects associated with given request';


--
-- Name: public_request_state_request_map; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE public_request_state_request_map (
    state_request_id integer NOT NULL,
    block_request_id integer NOT NULL,
    unblock_request_id integer
);


ALTER TABLE public.public_request_state_request_map OWNER TO fred;

--
-- Name: TABLE public_request_state_request_map; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE public_request_state_request_map IS 'table with state request associated with given request';


--
-- Name: registrar; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE registrar (
    id integer NOT NULL,
    ico character varying(50),
    dic character varying(50),
    varsymb character(10),
    vat boolean DEFAULT true,
    handle character varying(255) NOT NULL,
    name character varying(1024),
    organization character varying(1024),
    street1 character varying(1024),
    street2 character varying(1024),
    street3 character varying(1024),
    city character varying(1024),
    stateorprovince character varying(1024),
    postalcode character varying(32),
    country character(2),
    telephone character varying(32),
    fax character varying(32),
    email character varying(1024),
    url character varying(1024),
    system boolean DEFAULT false,
    regex character varying(30) DEFAULT NULL::character varying
);


ALTER TABLE public.registrar OWNER TO fred;

--
-- Name: TABLE registrar; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE registrar IS 'Evidence of registrars, who can create or change administered object via register';


--
-- Name: COLUMN registrar.id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar.id IS 'unique automatically generated identifier';


--
-- Name: COLUMN registrar.ico; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar.ico IS 'organization identification number';


--
-- Name: COLUMN registrar.dic; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar.dic IS 'tax identification number';


--
-- Name: COLUMN registrar.varsymb; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar.varsymb IS 'coupling variable symbol (ico)';


--
-- Name: COLUMN registrar.vat; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar.vat IS 'whether VAT should be count in invoicing';


--
-- Name: COLUMN registrar.handle; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar.handle IS 'unique text string identifying registrar, it is generated by system admin when new registrar is created';


--
-- Name: COLUMN registrar.name; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar.name IS 'registrats name';


--
-- Name: COLUMN registrar.organization; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar.organization IS 'Official company name';


--
-- Name: COLUMN registrar.street1; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar.street1 IS 'part of address';


--
-- Name: COLUMN registrar.street2; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar.street2 IS 'part of address';


--
-- Name: COLUMN registrar.street3; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar.street3 IS 'part of address';


--
-- Name: COLUMN registrar.city; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar.city IS 'part of address - city';


--
-- Name: COLUMN registrar.stateorprovince; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar.stateorprovince IS 'part of address - region';


--
-- Name: COLUMN registrar.postalcode; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar.postalcode IS 'part of address - postal code';


--
-- Name: COLUMN registrar.country; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar.country IS 'code for country from enum_country table';


--
-- Name: COLUMN registrar.telephone; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar.telephone IS 'phone number';


--
-- Name: COLUMN registrar.fax; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar.fax IS 'fax number';


--
-- Name: COLUMN registrar.email; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar.email IS 'e-mail address';


--
-- Name: COLUMN registrar.url; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar.url IS 'registrars web address';


--
-- Name: registrar_certification; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE registrar_certification (
    id integer NOT NULL,
    registrar_id integer NOT NULL,
    valid_from date NOT NULL,
    valid_until date NOT NULL,
    classification classification_type NOT NULL,
    eval_file_id integer NOT NULL
);


ALTER TABLE public.registrar_certification OWNER TO fred;

--
-- Name: TABLE registrar_certification; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE registrar_certification IS 'result of registrar certification';


--
-- Name: COLUMN registrar_certification.registrar_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar_certification.registrar_id IS 'certified registrar id';


--
-- Name: COLUMN registrar_certification.valid_from; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar_certification.valid_from IS 'certification is valid from this date';


--
-- Name: COLUMN registrar_certification.valid_until; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar_certification.valid_until IS 'certification is valid until this date, certification should be valid for 1 year';


--
-- Name: COLUMN registrar_certification.classification; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar_certification.classification IS 'registrar certification result checked 0-5';


--
-- Name: COLUMN registrar_certification.eval_file_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar_certification.eval_file_id IS 'evaluation pdf file link';


--
-- Name: registrar_certification_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE registrar_certification_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.registrar_certification_id_seq OWNER TO fred;

--
-- Name: registrar_certification_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE registrar_certification_id_seq OWNED BY registrar_certification.id;


--
-- Name: registrar_certification_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('registrar_certification_id_seq', 1, true);


--
-- Name: registrar_credit; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE registrar_credit (
    id bigint NOT NULL,
    credit numeric(30,2) DEFAULT 0 NOT NULL,
    registrar_id bigint NOT NULL,
    zone_id bigint NOT NULL
);


ALTER TABLE public.registrar_credit OWNER TO fred;

--
-- Name: TABLE registrar_credit; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE registrar_credit IS 'current credit by registrar and zone';


--
-- Name: registrar_credit_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE registrar_credit_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.registrar_credit_id_seq OWNER TO fred;

--
-- Name: registrar_credit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE registrar_credit_id_seq OWNED BY registrar_credit.id;


--
-- Name: registrar_credit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('registrar_credit_id_seq', 9, true);


--
-- Name: registrar_credit_transaction; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE registrar_credit_transaction (
    id bigint NOT NULL,
    balance_change numeric(10,2) NOT NULL,
    registrar_credit_id bigint NOT NULL
);


ALTER TABLE public.registrar_credit_transaction OWNER TO fred;

--
-- Name: TABLE registrar_credit_transaction; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE registrar_credit_transaction IS 'balance changes';


--
-- Name: registrar_credit_transaction_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE registrar_credit_transaction_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.registrar_credit_transaction_id_seq OWNER TO fred;

--
-- Name: registrar_credit_transaction_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE registrar_credit_transaction_id_seq OWNED BY registrar_credit_transaction.id;


--
-- Name: registrar_credit_transaction_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('registrar_credit_transaction_id_seq', 74, true);


--
-- Name: registrar_disconnect; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE registrar_disconnect (
    id integer NOT NULL,
    registrarid integer NOT NULL,
    blocked_from timestamp without time zone DEFAULT now() NOT NULL,
    blocked_to timestamp without time zone,
    unblock_request_id bigint
);


ALTER TABLE public.registrar_disconnect OWNER TO fred;

--
-- Name: registrar_disconnect_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE registrar_disconnect_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.registrar_disconnect_id_seq OWNER TO fred;

--
-- Name: registrar_disconnect_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE registrar_disconnect_id_seq OWNED BY registrar_disconnect.id;


--
-- Name: registrar_disconnect_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('registrar_disconnect_id_seq', 1, false);


--
-- Name: registrar_group; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE registrar_group (
    id integer NOT NULL,
    short_name character varying(255) NOT NULL,
    cancelled timestamp without time zone
);


ALTER TABLE public.registrar_group OWNER TO fred;

--
-- Name: TABLE registrar_group; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE registrar_group IS 'available groups of registars';


--
-- Name: COLUMN registrar_group.id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar_group.id IS 'group id';


--
-- Name: COLUMN registrar_group.short_name; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar_group.short_name IS 'group short name';


--
-- Name: COLUMN registrar_group.cancelled; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar_group.cancelled IS 'time when the group was cancelled';


--
-- Name: registrar_group_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE registrar_group_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.registrar_group_id_seq OWNER TO fred;

--
-- Name: registrar_group_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE registrar_group_id_seq OWNED BY registrar_group.id;


--
-- Name: registrar_group_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('registrar_group_id_seq', 5, true);


--
-- Name: registrar_group_map; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE registrar_group_map (
    id integer NOT NULL,
    registrar_id integer NOT NULL,
    registrar_group_id integer NOT NULL,
    member_from date NOT NULL,
    member_until date
);


ALTER TABLE public.registrar_group_map OWNER TO fred;

--
-- Name: TABLE registrar_group_map; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE registrar_group_map IS 'membership of registar in group';


--
-- Name: COLUMN registrar_group_map.id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar_group_map.id IS 'registrar group membership id';


--
-- Name: COLUMN registrar_group_map.registrar_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar_group_map.registrar_id IS 'registrar id';


--
-- Name: COLUMN registrar_group_map.registrar_group_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar_group_map.registrar_group_id IS 'group id';


--
-- Name: COLUMN registrar_group_map.member_from; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar_group_map.member_from IS 'registrar membership in the group from this date';


--
-- Name: COLUMN registrar_group_map.member_until; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrar_group_map.member_until IS 'registrar membership in the group until this date or unspecified';


--
-- Name: registrar_group_map_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE registrar_group_map_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.registrar_group_map_id_seq OWNER TO fred;

--
-- Name: registrar_group_map_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE registrar_group_map_id_seq OWNED BY registrar_group_map.id;


--
-- Name: registrar_group_map_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('registrar_group_map_id_seq', 6, true);


--
-- Name: registrar_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE registrar_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.registrar_id_seq OWNER TO fred;

--
-- Name: registrar_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE registrar_id_seq OWNED BY registrar.id;


--
-- Name: registrar_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('registrar_id_seq', 5, true);


--
-- Name: registraracl; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE registraracl (
    id integer NOT NULL,
    registrarid integer NOT NULL,
    cert character varying(1024) NOT NULL,
    password character varying(64) NOT NULL
);


ALTER TABLE public.registraracl OWNER TO fred;

--
-- Name: TABLE registraracl; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE registraracl IS 'Registrars login information';


--
-- Name: COLUMN registraracl.cert; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registraracl.cert IS 'certificate fingerprint';


--
-- Name: COLUMN registraracl.password; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registraracl.password IS 'login password';


--
-- Name: registraracl_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE registraracl_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.registraracl_id_seq OWNER TO fred;

--
-- Name: registraracl_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE registraracl_id_seq OWNED BY registraracl.id;


--
-- Name: registraracl_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('registraracl_id_seq', 6, true);


--
-- Name: registrarinvoice; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE registrarinvoice (
    id integer NOT NULL,
    registrarid integer NOT NULL,
    zone integer NOT NULL,
    fromdate date NOT NULL,
    todate date
);


ALTER TABLE public.registrarinvoice OWNER TO fred;

--
-- Name: COLUMN registrarinvoice.zone; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrarinvoice.zone IS 'zone for which has registrar an access';


--
-- Name: COLUMN registrarinvoice.fromdate; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrarinvoice.fromdate IS 'date when began registrar work in a zone';


--
-- Name: COLUMN registrarinvoice.todate; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN registrarinvoice.todate IS 'after this date, registrar is not allowed to register';


--
-- Name: registrarinvoice_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE registrarinvoice_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.registrarinvoice_id_seq OWNER TO fred;

--
-- Name: registrarinvoice_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE registrarinvoice_id_seq OWNED BY registrarinvoice.id;


--
-- Name: registrarinvoice_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('registrarinvoice_id_seq', 9, true);


--
-- Name: reminder_contact_message_map; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE reminder_contact_message_map (
    reminder_date date NOT NULL,
    contact_id integer NOT NULL,
    message_id integer
);


ALTER TABLE public.reminder_contact_message_map OWNER TO fred;

--
-- Name: reminder_registrar_parameter; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE reminder_registrar_parameter (
    registrar_id integer NOT NULL,
    template_memo text,
    reply_to character varying(200)
);


ALTER TABLE public.reminder_registrar_parameter OWNER TO fred;

--
-- Name: request; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE request (
    id bigint NOT NULL,
    time_begin timestamp without time zone NOT NULL,
    time_end timestamp without time zone,
    source_ip inet,
    service_id integer NOT NULL,
    request_type_id integer DEFAULT 1000,
    session_id bigint,
    user_name character varying(255),
    is_monitoring boolean NOT NULL,
    result_code_id integer,
    user_id integer
);


ALTER TABLE public.request OWNER TO fred;

--
-- Name: COLUMN request.result_code_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN request.result_code_id IS 'result code as returned by the specific service, it''s only unique within the service';


--
-- Name: request_data; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE request_data (
    id bigint NOT NULL,
    request_time_begin timestamp without time zone NOT NULL,
    request_service_id integer NOT NULL,
    request_monitoring boolean NOT NULL,
    request_id bigint NOT NULL,
    content text NOT NULL,
    is_response boolean DEFAULT false
);


ALTER TABLE public.request_data OWNER TO fred;

--
-- Name: request_data_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE request_data_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.request_data_id_seq OWNER TO fred;

--
-- Name: request_data_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE request_data_id_seq OWNED BY request_data.id;


--
-- Name: request_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('request_data_id_seq', 348, true);


--
-- Name: request_data_epp_13_06; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE request_data_epp_13_06 (CONSTRAINT request_data_epp_13_06_check CHECK (((((request_time_begin >= '2013-06-01 00:00:00'::timestamp without time zone) AND (request_time_begin < '2013-07-01 00:00:00'::timestamp without time zone)) AND (request_service_id = 3)) AND (request_monitoring = false)))
)
INHERITS (request_data);


ALTER TABLE public.request_data_epp_13_06 OWNER TO fred;

--
-- Name: request_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE request_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.request_id_seq OWNER TO fred;

--
-- Name: request_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE request_id_seq OWNED BY request.id;


--
-- Name: request_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('request_id_seq', 174, true);


--
-- Name: request_epp_13_06; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE request_epp_13_06 (CONSTRAINT request_epp_13_06_check CHECK (((((time_begin >= '2013-06-01 00:00:00'::timestamp without time zone) AND (time_begin < '2013-07-01 00:00:00'::timestamp without time zone)) AND (service_id = 3)) AND (is_monitoring = false)))
)
INHERITS (request);


ALTER TABLE public.request_epp_13_06 OWNER TO fred;

--
-- Name: request_fee_parameter; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE request_fee_parameter (
    id integer NOT NULL,
    valid_from timestamp without time zone NOT NULL,
    count_free_base integer,
    count_free_per_domain integer,
    zone_id integer NOT NULL
);


ALTER TABLE public.request_fee_parameter OWNER TO fred;

--
-- Name: request_fee_registrar_parameter; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE request_fee_registrar_parameter (
    registrar_id integer NOT NULL,
    request_price_limit numeric(10,2) NOT NULL,
    email character varying(200) NOT NULL,
    telephone character varying(64) NOT NULL
);


ALTER TABLE public.request_fee_registrar_parameter OWNER TO fred;

--
-- Name: request_object_ref; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE request_object_ref (
    id bigint NOT NULL,
    request_time_begin timestamp without time zone NOT NULL,
    request_service_id integer NOT NULL,
    request_monitoring boolean NOT NULL,
    request_id bigint NOT NULL,
    object_type_id integer NOT NULL,
    object_id integer NOT NULL
);


ALTER TABLE public.request_object_ref OWNER TO fred;

--
-- Name: request_object_ref_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE request_object_ref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.request_object_ref_id_seq OWNER TO fred;

--
-- Name: request_object_ref_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE request_object_ref_id_seq OWNED BY request_object_ref.id;


--
-- Name: request_object_ref_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('request_object_ref_id_seq', 1, false);


--
-- Name: request_object_type; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE request_object_type (
    id integer NOT NULL,
    name character varying(64)
);


ALTER TABLE public.request_object_type OWNER TO fred;

--
-- Name: request_object_type_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE request_object_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.request_object_type_id_seq OWNER TO fred;

--
-- Name: request_object_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE request_object_type_id_seq OWNED BY request_object_type.id;


--
-- Name: request_object_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('request_object_type_id_seq', 1, false);


--
-- Name: request_property_name; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE request_property_name (
    id integer NOT NULL,
    name character varying(256) NOT NULL
);


ALTER TABLE public.request_property_name OWNER TO fred;

--
-- Name: request_property_name_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE request_property_name_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.request_property_name_id_seq OWNER TO fred;

--
-- Name: request_property_name_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE request_property_name_id_seq OWNED BY request_property_name.id;


--
-- Name: request_property_name_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('request_property_name_id_seq', 301, true);


--
-- Name: request_property_value; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE request_property_value (
    request_time_begin timestamp without time zone NOT NULL,
    request_service_id integer NOT NULL,
    request_monitoring boolean NOT NULL,
    id bigint NOT NULL,
    request_id bigint NOT NULL,
    property_name_id integer NOT NULL,
    value text NOT NULL,
    output boolean DEFAULT false,
    parent_id bigint
);


ALTER TABLE public.request_property_value OWNER TO fred;

--
-- Name: request_property_value_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE request_property_value_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.request_property_value_id_seq OWNER TO fred;

--
-- Name: request_property_value_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE request_property_value_id_seq OWNED BY request_property_value.id;


--
-- Name: request_property_value_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('request_property_value_id_seq', 1510, true);


--
-- Name: request_property_value_epp_13_06; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE request_property_value_epp_13_06 (CONSTRAINT request_property_value_epp_13_06_check CHECK (((((request_time_begin >= '2013-06-01 00:00:00'::timestamp without time zone) AND (request_time_begin < '2013-07-01 00:00:00'::timestamp without time zone)) AND (request_service_id = 3)) AND (request_monitoring = false)))
)
INHERITS (request_property_value);


ALTER TABLE public.request_property_value_epp_13_06 OWNER TO fred;

--
-- Name: request_type; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE request_type (
    id integer NOT NULL,
    name character varying(64) NOT NULL,
    service_id integer NOT NULL
);


ALTER TABLE public.request_type OWNER TO fred;

--
-- Name: TABLE request_type; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE request_type IS 'List of requests which can be used by clients

id  - status
100 - ClientLogin
101 - ClientLogout
105 - ClientGreeting
120 - PollAcknowledgement
121 - PollResponse
200 - ContactCheck
201 - ContactInfo
202 - ContactDelete
203 - ContactUpdate
204 - ContactCreate
205 - ContactTransfer
400 - NSsetCheck
401 - NSsetInfo
402 - NSsetDelete
403 - NSsetUpdate
404 - NSsetCreate
405 - NSsetTransfer
500 - DomainCheck
501 - DomainInfo
502 - DomainDelete
503 - DomainUpdate
504 - DomainCreate
505 - DomainTransfer
506 - DomainRenew
507 - DomainTrade
600 - KeysetCheck
601 - KeysetInfo
602 - KeysetDelete
603 - KeysetUpdate
604 - KeysetCreate
605 - KeysetTransfer
1000 - UnknownAction
1002 - ListContact
1004 - ListNSset
1005 - ListDomain
1006 - ListKeySet
1010 - ClientCredit
1012 - nssetTest
1101 - ContactSendAuthInfo
1102 - NSSetSendAuthInfo
1103 - DomainSendAuthInfo
1104 - Info
1106 - KeySetSendAuthInfo
1200 - InfoListContacts
1201 - InfoListDomains
1202 - InfoListNssets
1203 - InfoListKeysets
1204 - InfoDomainsByNsset
1205 - InfoDomainsByKeyset
1206 - InfoDomainsByContact
1207 - InfoNssetsByContact
1208 - InfoNssetsByNs
1209 - InfoKeysetsByContact
1210 - InfoGetResults

1300 - Login
1301 - Logout
1302 - DomainFilter
1303 - ContactFilter
1304 - NSSetFilter
1305 - KeySetFilter
1306 - RegistrarFilter
1307 - InvoiceFilter
1308 - EmailsFilter
1309 - FileFilter
1310 - ActionsFilter
1311 - PublicRequestFilter

1312 - DomainDetail
1313 - ContactDetail
1314 - NSSetDetail
1315 - KeySetDetail
1316 - RegistrarDetail
1317 - InvoiceDetail
1318 - EmailsDetail
1319 - FileDetail
1320 - ActionsDetail
1321 - PublicRequestDetail

1322 - RegistrarCreate
1323 - RegistrarUpdate

1324 - PublicRequestAccept
1325 - PublicRequestInvalidate

1326 - DomainDig
1327 - FilterCreate

1328 - RequestDetail
1329 - RequestFilter

1330 - BankStatementDetail
1331 - BankStatementFilter

1400 -  Login
1401 -  Logout

1402 -  DisplaySummary
1403 -  InvoiceList
1404 -  DomainList
1405 -  FileDetail';


--
-- Name: request_type_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE request_type_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.request_type_id_seq OWNER TO fred;

--
-- Name: request_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE request_type_id_seq OWNED BY request_type.id;


--
-- Name: request_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('request_type_id_seq', 1706, true);


--
-- Name: result_code; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE result_code (
    id integer NOT NULL,
    service_id integer,
    result_code integer NOT NULL,
    name character varying(64) NOT NULL
);


ALTER TABLE public.result_code OWNER TO fred;

--
-- Name: TABLE result_code; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE result_code IS 'all possible operation result codes';


--
-- Name: COLUMN result_code.id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN result_code.id IS 'result_code id';


--
-- Name: COLUMN result_code.service_id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN result_code.service_id IS 'reference to service table. This is needed to distinguish entries with identical result_code values';


--
-- Name: COLUMN result_code.result_code; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN result_code.result_code IS 'result code as returned by the specific service, it''s only unique within the service';


--
-- Name: COLUMN result_code.name; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN result_code.name IS 'short name for error (abbreviation) written in camelcase';


--
-- Name: result_code_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE result_code_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.result_code_id_seq OWNER TO fred;

--
-- Name: result_code_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE result_code_id_seq OWNED BY result_code.id;


--
-- Name: result_code_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('result_code_id_seq', 56, true);


--
-- Name: service; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE service (
    id integer NOT NULL,
    partition_postfix character varying(10) NOT NULL,
    name character varying(64) NOT NULL
);


ALTER TABLE public.service OWNER TO fred;

--
-- Name: service_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE service_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.service_id_seq OWNER TO fred;

--
-- Name: service_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE service_id_seq OWNED BY service.id;


--
-- Name: service_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('service_id_seq', 1, false);


--
-- Name: session; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE session (
    id bigint NOT NULL,
    user_name character varying(255) NOT NULL,
    login_date timestamp without time zone NOT NULL,
    logout_date timestamp without time zone,
    user_id integer
);


ALTER TABLE public.session OWNER TO fred;

--
-- Name: session_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE session_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.session_id_seq OWNER TO fred;

--
-- Name: session_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE session_id_seq OWNED BY session.id;


--
-- Name: session_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('session_id_seq', 58, true);


--
-- Name: session_13_06; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE session_13_06 (CONSTRAINT session_13_06_login_date_check CHECK (((login_date >= '2013-06-01 00:00:00'::timestamp without time zone) AND (login_date < '2013-07-01 00:00:00'::timestamp without time zone)))
)
INHERITS (session);


ALTER TABLE public.session_13_06 OWNER TO fred;

--
-- Name: sms_archive; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE sms_archive (
    id integer NOT NULL,
    phone_number character varying(64) NOT NULL,
    phone_number_id integer,
    content text
);


ALTER TABLE public.sms_archive OWNER TO fred;

--
-- Name: user; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE "user" (
    id integer NOT NULL,
    firstname character varying(20) NOT NULL,
    surname character varying(40) NOT NULL
);


ALTER TABLE public."user" OWNER TO fred;

--
-- Name: user_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.user_id_seq OWNER TO fred;

--
-- Name: user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE user_id_seq OWNED BY "user".id;


--
-- Name: user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('user_id_seq', 1, false);


--
-- Name: zone; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE zone (
    id integer NOT NULL,
    fqdn character varying(255) NOT NULL,
    ex_period_min integer NOT NULL,
    ex_period_max integer NOT NULL,
    val_period integer NOT NULL,
    dots_max integer DEFAULT 1 NOT NULL,
    enum_zone boolean DEFAULT false,
    warning_letter boolean DEFAULT true NOT NULL
);


ALTER TABLE public.zone OWNER TO fred;

--
-- Name: TABLE zone; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE zone IS 'This table contains zone parameters';


--
-- Name: COLUMN zone.id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN zone.id IS 'unique automatically generated identifier';


--
-- Name: COLUMN zone.fqdn; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN zone.fqdn IS 'zone fully qualified name';


--
-- Name: COLUMN zone.ex_period_min; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN zone.ex_period_min IS 'minimal prolongation of the period of domains validity in months';


--
-- Name: COLUMN zone.ex_period_max; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN zone.ex_period_max IS 'maximal prolongation of the period of domains validity in months';


--
-- Name: COLUMN zone.val_period; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN zone.val_period IS 'enum domains revalidation period in months';


--
-- Name: COLUMN zone.dots_max; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN zone.dots_max IS 'maximal number of dots in zone name';


--
-- Name: COLUMN zone.enum_zone; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN zone.enum_zone IS 'flag if zone is for enum';


--
-- Name: zone_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE zone_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.zone_id_seq OWNER TO fred;

--
-- Name: zone_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE zone_id_seq OWNED BY zone.id;


--
-- Name: zone_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('zone_id_seq', 2, true);


--
-- Name: zone_ns; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE zone_ns (
    id integer NOT NULL,
    zone integer,
    fqdn character varying(255) NOT NULL,
    addrs inet[] NOT NULL
);


ALTER TABLE public.zone_ns OWNER TO fred;

--
-- Name: TABLE zone_ns; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE zone_ns IS 'This table contains nameservers for a zone';


--
-- Name: COLUMN zone_ns.id; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN zone_ns.id IS 'unique automatically generated identifier';


--
-- Name: COLUMN zone_ns.zone; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN zone_ns.zone IS 'zone id';


--
-- Name: COLUMN zone_ns.fqdn; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN zone_ns.fqdn IS 'nameserver ip addresses array';


--
-- Name: zone_ns_id_seq; Type: SEQUENCE; Schema: public; Owner: fred
--

CREATE SEQUENCE zone_ns_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.zone_ns_id_seq OWNER TO fred;

--
-- Name: zone_ns_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fred
--

ALTER SEQUENCE zone_ns_id_seq OWNED BY zone_ns.id;


--
-- Name: zone_ns_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fred
--

SELECT pg_catalog.setval('zone_ns_id_seq', 10, true);


--
-- Name: zone_soa; Type: TABLE; Schema: public; Owner: fred; Tablespace:
--

CREATE TABLE zone_soa (
    zone integer NOT NULL,
    ttl integer NOT NULL,
    hostmaster character varying(255) NOT NULL,
    serial integer,
    refresh integer NOT NULL,
    update_retr integer NOT NULL,
    expiry integer NOT NULL,
    minimum integer NOT NULL,
    ns_fqdn character varying(255) NOT NULL
);


ALTER TABLE public.zone_soa OWNER TO fred;

--
-- Name: TABLE zone_soa; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON TABLE zone_soa IS 'Table holding data from SOA record for a zone';


--
-- Name: COLUMN zone_soa.zone; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN zone_soa.zone IS 'zone id';


--
-- Name: COLUMN zone_soa.ttl; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN zone_soa.ttl IS 'default period of validity of records in the zone in seconds';


--
-- Name: COLUMN zone_soa.hostmaster; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN zone_soa.hostmaster IS 'responsible person email (in format: user@domain.tld )';


--
-- Name: COLUMN zone_soa.serial; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN zone_soa.serial IS 'serial number incremented on change in the form YYYYMMDDnn (year, month, date, revision)';


--
-- Name: COLUMN zone_soa.refresh; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN zone_soa.refresh IS 'secondary nameservers copy of zone refresh interval in seconds';


--
-- Name: COLUMN zone_soa.update_retr; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN zone_soa.update_retr IS 'retry interval of secondary nameservers zone update (in case of failed zone refresh) in seconds';


--
-- Name: COLUMN zone_soa.expiry; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN zone_soa.expiry IS 'zone expiration period for secondary nameservers in seconds';


--
-- Name: COLUMN zone_soa.minimum; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN zone_soa.minimum IS 'the time a NAME ERROR = NXDOMAIN result may be cached by any resolver in seconds';


--
-- Name: COLUMN zone_soa.ns_fqdn; Type: COMMENT; Schema: public; Owner: fred
--

COMMENT ON COLUMN zone_soa.ns_fqdn IS 'primary nameserver fully qualified name';


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE bank_account ALTER COLUMN id SET DEFAULT nextval('bank_account_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE bank_payment ALTER COLUMN id SET DEFAULT nextval('bank_payment_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE bank_payment_registrar_credit_transaction_map ALTER COLUMN id SET DEFAULT nextval('bank_payment_registrar_credit_transaction_map_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE bank_statement ALTER COLUMN id SET DEFAULT nextval('bank_statement_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE check_dependance ALTER COLUMN id SET DEFAULT nextval('check_dependance_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE check_nsset ALTER COLUMN id SET DEFAULT nextval('check_nsset_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE check_result ALTER COLUMN id SET DEFAULT nextval('check_result_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE comm_type ALTER COLUMN id SET DEFAULT nextval('comm_type_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE dnskey ALTER COLUMN id SET DEFAULT nextval('dnskey_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE domain_blacklist ALTER COLUMN id SET DEFAULT nextval('domain_blacklist_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE dsrecord ALTER COLUMN id SET DEFAULT nextval('dsrecord_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE enum_error ALTER COLUMN id SET DEFAULT nextval('enum_error_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE enum_operation ALTER COLUMN id SET DEFAULT nextval('enum_operation_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE enum_reason ALTER COLUMN id SET DEFAULT nextval('enum_reason_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE enum_ssntype ALTER COLUMN id SET DEFAULT nextval('enum_ssntype_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE files ALTER COLUMN id SET DEFAULT nextval('files_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE filters ALTER COLUMN id SET DEFAULT nextval('filters_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE genzone_domain_history ALTER COLUMN id SET DEFAULT nextval('genzone_domain_history_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE history ALTER COLUMN id SET DEFAULT nextval('history_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE host ALTER COLUMN id SET DEFAULT nextval('host_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE host_ipaddr_map ALTER COLUMN id SET DEFAULT nextval('host_ipaddr_map_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE invoice ALTER COLUMN id SET DEFAULT nextval('invoice_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE invoice_generation ALTER COLUMN id SET DEFAULT nextval('invoice_generation_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE invoice_mails ALTER COLUMN id SET DEFAULT nextval('invoice_mails_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE invoice_number_prefix ALTER COLUMN id SET DEFAULT nextval('invoice_number_prefix_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE invoice_operation ALTER COLUMN id SET DEFAULT nextval('invoice_operation_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE invoice_prefix ALTER COLUMN id SET DEFAULT nextval('invoice_prefix_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE invoice_registrar_credit_transaction_map ALTER COLUMN id SET DEFAULT nextval('invoice_registrar_credit_transaction_map_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE invoice_type ALTER COLUMN id SET DEFAULT nextval('invoice_type_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE mail_archive ALTER COLUMN id SET DEFAULT nextval('mail_archive_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE mail_attachments ALTER COLUMN id SET DEFAULT nextval('mail_attachments_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE mail_defaults ALTER COLUMN id SET DEFAULT nextval('mail_defaults_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE mail_handles ALTER COLUMN id SET DEFAULT nextval('mail_handles_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE mail_header_defaults ALTER COLUMN id SET DEFAULT nextval('mail_header_defaults_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE mail_vcard ALTER COLUMN id SET DEFAULT nextval('mail_vcard_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE message ALTER COLUMN id SET DEFAULT nextval('message_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE message_archive ALTER COLUMN id SET DEFAULT nextval('message_archive_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE message_contact_history_map ALTER COLUMN id SET DEFAULT nextval('message_contact_history_map_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE message_type ALTER COLUMN id SET DEFAULT nextval('message_type_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE object_registry ALTER COLUMN id SET DEFAULT nextval('object_registry_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE object_state ALTER COLUMN id SET DEFAULT nextval('object_state_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE object_state_request ALTER COLUMN id SET DEFAULT nextval('object_state_request_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE object_state_request_lock ALTER COLUMN id SET DEFAULT nextval('object_state_request_lock_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE price_list ALTER COLUMN id SET DEFAULT nextval('price_list_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE price_vat ALTER COLUMN id SET DEFAULT nextval('price_vat_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE public_request ALTER COLUMN id SET DEFAULT nextval('public_request_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE public_request_lock ALTER COLUMN id SET DEFAULT nextval('public_request_lock_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE public_request_messages_map ALTER COLUMN id SET DEFAULT nextval('public_request_messages_map_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE registrar ALTER COLUMN id SET DEFAULT nextval('registrar_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE registrar_certification ALTER COLUMN id SET DEFAULT nextval('registrar_certification_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE registrar_credit ALTER COLUMN id SET DEFAULT nextval('registrar_credit_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE registrar_credit_transaction ALTER COLUMN id SET DEFAULT nextval('registrar_credit_transaction_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE registrar_disconnect ALTER COLUMN id SET DEFAULT nextval('registrar_disconnect_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE registrar_group ALTER COLUMN id SET DEFAULT nextval('registrar_group_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE registrar_group_map ALTER COLUMN id SET DEFAULT nextval('registrar_group_map_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE registraracl ALTER COLUMN id SET DEFAULT nextval('registraracl_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE registrarinvoice ALTER COLUMN id SET DEFAULT nextval('registrarinvoice_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE request ALTER COLUMN id SET DEFAULT nextval('request_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE request_data ALTER COLUMN id SET DEFAULT nextval('request_data_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE request_object_ref ALTER COLUMN id SET DEFAULT nextval('request_object_ref_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE request_object_type ALTER COLUMN id SET DEFAULT nextval('request_object_type_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE request_property_name ALTER COLUMN id SET DEFAULT nextval('request_property_name_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE request_property_value ALTER COLUMN id SET DEFAULT nextval('request_property_value_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE request_type ALTER COLUMN id SET DEFAULT nextval('request_type_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE result_code ALTER COLUMN id SET DEFAULT nextval('result_code_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE service ALTER COLUMN id SET DEFAULT nextval('service_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE session ALTER COLUMN id SET DEFAULT nextval('session_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE "user" ALTER COLUMN id SET DEFAULT nextval('user_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE zone ALTER COLUMN id SET DEFAULT nextval('zone_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fred
--

ALTER TABLE zone_ns ALTER COLUMN id SET DEFAULT nextval('zone_ns_id_seq'::regclass);


--
-- Data for Name: bank_account; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY bank_account (id, zone, account_number, account_name, bank_code, balance, last_date, last_num) FROM stdin;
1	1	756             	ENUM ucet ebanka    	2400	0.00	\N	\N
2	1	210345314       	CSOB enum           	0300	0.00	\N	\N
3	2	617             	EBanka .cz          	2400	0.00	\N	\N
4	2	188208275       	CSOB .cz            	0300	0.00	\N	\N
5	1	756             	Raiffeisen - enum   	5500	0.00	\N	\N
6	2	617             	Raiffeisen - cz     	5500	0.00	\N	\N
7	\N	36153615        	Akademie            	0300	0.00	\N	\N
8	2	2700342289      	Fio - cz            	2010	0.00	\N	\N
\.


--
-- Data for Name: bank_payment; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY bank_payment (id, statement_id, account_id, account_number, bank_code, code, type, status, konstsym, varsymb, specsymb, price, account_evid, account_date, account_memo, account_name, crtime) FROM stdin;
1	1	6	132145762	0300	1	2	1	\N	12345	\N	1000.00	12	2011-02-01	Pokusny presun	Company A l.t.d	2013-06-14 13:29:05.740021
2	2	4	132145762	0300	1	2	1	\N	12346	\N	1000.00	13	2011-02-01	Pokusny presun	Company B l.t.d	2013-06-14 13:29:05.740021
3	3	5	132145762	0300	1	2	1	\N	12345	\N	1000.00	14	2011-02-01	Pokusny presun	Company A l.t.d	2013-06-14 13:29:05.740021
4	4	2	132145762	0300	1	2	1	\N	12346	\N	1000.00	15	2011-02-01	Pokusny presun	Company B l.t.d	2013-06-14 13:29:05.740021
5	5	6	132145762	0300	1	2	1	\N	12346	\N	1000.00	16	2011-02-01	Pokusny presun	Company A l.t.d	2013-06-14 13:29:05.740021
6	6	4	132145762	0300	1	2	1	\N	12346	\N	1000.00	17	2011-02-01	Pokusny presun	Company B l.t.d	2013-06-14 13:29:05.740021
\.


--
-- Data for Name: bank_payment_registrar_credit_transaction_map; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY bank_payment_registrar_credit_transaction_map (id, bank_payment_id, registrar_credit_transaction_id) FROM stdin;
1	1	7
2	2	8
3	3	9
4	4	10
5	5	11
6	6	12
\.


--
-- Data for Name: bank_statement; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY bank_statement (id, account_id, num, create_date, balance_old_date, balance_old, balance_new, balance_credit, balance_debet, file_id) FROM stdin;
1	6	1	2011-02-01	2011-02-01	0.00	0.00	0.00	0.00	2
2	4	2	2011-02-01	2011-02-01	0.00	0.00	0.00	0.00	3
3	5	3	2011-02-01	2011-02-01	0.00	0.00	0.00	0.00	4
4	2	4	2011-02-01	2011-02-01	0.00	0.00	0.00	0.00	5
5	6	5	2011-02-01	2011-02-01	0.00	0.00	0.00	0.00	6
6	4	6	2011-02-01	2011-02-01	0.00	0.00	0.00	0.00	7
\.


--
-- Data for Name: check_dependance; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY check_dependance (id, addictid, testid) FROM stdin;
1	1	0
2	10	0
3	20	0
4	30	0
5	40	0
6	50	0
7	60	0
8	10	1
9	20	1
10	30	1
11	30	20
12	40	1
13	50	1
14	60	1
15	70	1
16	70	20
\.


--
-- Data for Name: check_nsset; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY check_nsset (id, nsset_hid, checkdate, reason, overallstatus, extra_fqdns, dig, attempt) FROM stdin;
\.


--
-- Data for Name: check_result; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY check_result (id, checkid, testid, status, note, data) FROM stdin;
\.


--
-- Data for Name: check_test; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY check_test (id, name, severity, description, disabled, script, need_domain) FROM stdin;
0	glue_ok	1		f		2
1	existence	1		f	existance.py	2
10	autonomous	5		f	autonomous.py	0
20	presence	2		f	presence.py	1
30	authoritative	3		f	authoritative.py	1
40	heterogenous	6		f	heterogenous.py	0
50	notrecursive	4		f	recursive.py	2
60	notrecursive4all	4		f	recursive4all.py	0
70	dnsseckeychase	3		f	dnsseckeychase.py	3
\.


--
-- Data for Name: comm_type; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY comm_type (id, type) FROM stdin;
1	email
2	letter
3	sms
4	registered_letter
\.


--
-- Data for Name: contact; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY contact (id, name, organization, street1, street2, street3, city, stateorprovince, postalcode, country, telephone, fax, email, disclosename, discloseorganization, discloseaddress, disclosetelephone, disclosefax, discloseemail, notifyemail, vat, ssn, ssntype, disclosevat, discloseident, disclosenotifyemail) FROM stdin;
1	Freddy First	Company Fred s.p.z.o.	Wallstreet 16/3	\N	\N	New York	\N	12601	CZ	+420.726123455	+420.726123456	freddy.first@nic.czcz	t	t	t	t	f	t	freddy+notify@nic.czcz	CZ1234567889	84956250	2	f	f	f
2	Řehoř Čihák	Firma Čihák a spol.	Přípotoční 16/3	\N	\N	Říčany u Prahy	\N	12601	CZ	+420.726123456	+420.726123455	rehor.cihak@nic.czcz	t	t	t	t	f	t	cihak+notify@nic.czcz	CZ1234567890	84956251	2	f	f	f
3	Pepa Zdepa	Firma Pepa s.r.o.	U práce 453	\N	\N	Praha	\N	12300	CZ	+420.726123457	+420.726123454	pepa.zdepa@nic.czcz	t	t	t	t	f	t	pepa+notify@nic.czcz	CZ1234567891	84956252	2	f	f	f
4	Anna Procházková	\N	Za želvami 32	\N	\N	Louňovice	\N	12808	CZ	+420.726123458	+420.726123453	anna.prochazkova@nic.czcz	t	t	t	t	f	t	anna+notify@nic.czcz	CZ1234567892	84956253	2	f	f	f
5	František Kocourek	\N	Žabovřesky 4567	\N	\N	Brno	\N	18000	CZ	+420.726123459	+420.726123452	franta.kocourek@nic.czcz	t	t	t	t	f	t	franta+notify@nic.czcz	CZ1234567893	84956254	2	f	f	f
6	Tomáš Tester	\N	Testovní 35	\N	\N	Plzeň	\N	16200	CZ	+420.726123460	+420.726123451	tomas.tester@nic.czcz	t	t	t	t	f	t	tester+notify@nic.czcz	CZ1234567894	84956253	2	f	f	f
7	Bobeš Šuflík	\N	Báňská 35	\N	\N	Domažlice	\N	18200	CZ	+420.726123461	+420.726123450	bobes.suflik@nic.czcz	t	t	t	t	f	t	bob+notify@nic.czcz	CZ1234567895	84956252	2	f	f	f
\.


--
-- Data for Name: contact_history; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY contact_history (historyid, id, name, organization, street1, street2, street3, city, stateorprovince, postalcode, country, telephone, fax, email, disclosename, discloseorganization, discloseaddress, disclosetelephone, disclosefax, discloseemail, notifyemail, vat, ssn, ssntype, disclosevat, discloseident, disclosenotifyemail) FROM stdin;
1	1	Freddy First	Company Fred s.p.z.o.	Wallstreet 16/3	\N	\N	New York	\N	12601	CZ	+420.726123455	+420.726123456	freddy.first@nic.czcz	t	t	t	t	f	t	freddy+notify@nic.czcz	CZ1234567889	84956250	2	f	f	f
2	2	Řehoř Čihák	Firma Čihák a spol.	Přípotoční 16/3	\N	\N	Říčany u Prahy	\N	12601	CZ	+420.726123456	+420.726123455	rehor.cihak@nic.czcz	t	t	t	t	f	t	cihak+notify@nic.czcz	CZ1234567890	84956251	2	f	f	f
3	3	Pepa Zdepa	Firma Pepa s.r.o.	U práce 453	\N	\N	Praha	\N	12300	CZ	+420.726123457	+420.726123454	pepa.zdepa@nic.czcz	t	t	t	t	f	t	pepa+notify@nic.czcz	CZ1234567891	84956252	2	f	f	f
4	4	Anna Procházková	\N	Za želvami 32	\N	\N	Louňovice	\N	12808	CZ	+420.726123458	+420.726123453	anna.prochazkova@nic.czcz	t	t	t	t	f	t	anna+notify@nic.czcz	CZ1234567892	84956253	2	f	f	f
5	5	František Kocourek	\N	Žabovřesky 4567	\N	\N	Brno	\N	18000	CZ	+420.726123459	+420.726123452	franta.kocourek@nic.czcz	t	t	t	t	f	t	franta+notify@nic.czcz	CZ1234567893	84956254	2	f	f	f
6	6	Tomáš Tester	\N	Testovní 35	\N	\N	Plzeň	\N	16200	CZ	+420.726123460	+420.726123451	tomas.tester@nic.czcz	t	t	t	t	f	t	tester+notify@nic.czcz	CZ1234567894	84956253	2	f	f	f
7	7	Bobeš Šuflík	\N	Báňská 35	\N	\N	Domažlice	\N	18200	CZ	+420.726123461	+420.726123450	bobes.suflik@nic.czcz	t	t	t	t	f	t	bob+notify@nic.czcz	CZ1234567895	84956252	2	f	f	f
\.


--
-- Data for Name: dnskey; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY dnskey (id, keysetid, flags, protocol, alg, key) FROM stdin;
1	18	257	3	5	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8
2	19	257	3	5	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8
3	20	257	3	5	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8
4	21	257	3	5	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8
5	22	257	3	5	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8
6	23	257	3	5	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8
7	24	257	3	5	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8
8	25	257	3	5	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8
9	26	257	3	5	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8
10	27	257	3	5	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8
\.


--
-- Data for Name: dnskey_history; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY dnskey_history (historyid, id, keysetid, flags, protocol, alg, key) FROM stdin;
18	1	18	257	3	5	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8
19	2	19	257	3	5	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8
20	3	20	257	3	5	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8
21	4	21	257	3	5	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8
22	5	22	257	3	5	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8
23	6	23	257	3	5	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8
24	7	24	257	3	5	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8
25	8	25	257	3	5	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8
26	9	26	257	3	5	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8
27	10	27	257	3	5	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8
\.


--
-- Data for Name: dnssec; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY dnssec (domainid, keytag, alg, digesttype, digest, maxsiglive, keyflags, keyprotocol, keyalg, pubkey) FROM stdin;
\.


--
-- Data for Name: domain; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY domain (id, zone, registrant, nsset, exdate, keyset) FROM stdin;
28	2	6	8	2016-06-14	18
29	2	6	8	2016-06-14	18
30	2	6	8	2016-06-14	18
31	2	6	8	2016-06-14	18
32	2	6	8	2016-06-14	18
33	2	6	8	2016-06-14	18
34	2	6	8	2016-06-14	18
35	2	6	8	2016-06-14	18
36	2	6	8	2016-06-14	18
37	2	6	8	2016-06-14	18
38	2	4	8	2016-06-14	18
39	2	4	8	2016-06-14	18
40	2	4	8	2016-06-14	18
41	2	4	8	2016-06-14	18
42	2	4	8	2016-06-14	18
43	2	4	8	2016-06-14	18
44	2	4	8	2016-06-14	18
45	2	4	8	2016-06-14	18
46	2	4	8	2016-06-14	18
47	2	4	8	2016-06-14	18
48	1	6	8	2014-06-14	18
49	1	6	8	2014-06-14	18
50	1	6	8	2014-06-14	18
51	1	6	8	2014-06-14	18
52	1	6	8	2014-06-14	18
53	1	6	8	2014-06-14	18
54	1	6	8	2014-06-14	18
55	1	6	8	2014-06-14	18
56	1	6	8	2014-06-14	18
57	1	6	8	2014-06-14	18
58	1	6	8	2014-06-14	18
\.


--
-- Data for Name: domain_blacklist; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY domain_blacklist (id, regexp, valid_from, valid_to, reason, creator) FROM stdin;
\.


--
-- Data for Name: domain_contact_map; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY domain_contact_map (domainid, contactid, role) FROM stdin;
28	4	1
28	6	1
29	4	1
29	6	1
30	4	1
30	6	1
31	4	1
31	6	1
32	4	1
32	6	1
33	4	1
33	6	1
34	4	1
34	6	1
35	4	1
35	6	1
36	4	1
36	6	1
37	4	1
37	6	1
38	6	1
39	6	1
40	6	1
41	6	1
42	6	1
43	6	1
44	6	1
45	6	1
46	6	1
47	6	1
48	4	1
48	7	1
49	4	1
49	7	1
50	4	1
50	7	1
51	4	1
51	7	1
52	4	1
52	7	1
53	4	1
53	7	1
54	4	1
54	7	1
55	4	1
55	7	1
56	4	1
56	7	1
57	4	1
57	7	1
58	4	1
58	7	1
\.


--
-- Data for Name: domain_contact_map_history; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY domain_contact_map_history (historyid, domainid, contactid, role) FROM stdin;
28	28	4	1
28	28	6	1
29	29	4	1
29	29	6	1
30	30	4	1
30	30	6	1
31	31	4	1
31	31	6	1
32	32	4	1
32	32	6	1
33	33	4	1
33	33	6	1
34	34	4	1
34	34	6	1
35	35	4	1
35	35	6	1
36	36	4	1
36	36	6	1
37	37	4	1
37	37	6	1
38	38	6	1
39	39	6	1
40	40	6	1
41	41	6	1
42	42	6	1
43	43	6	1
44	44	6	1
45	45	6	1
46	46	6	1
47	47	6	1
48	48	4	1
48	48	7	1
49	49	4	1
49	49	7	1
50	50	4	1
50	50	7	1
51	51	4	1
51	51	7	1
52	52	4	1
52	52	7	1
53	53	4	1
53	53	7	1
54	54	4	1
54	54	7	1
55	55	4	1
55	55	7	1
56	56	4	1
56	56	7	1
57	57	4	1
57	57	7	1
58	58	4	1
58	58	7	1
\.


--
-- Data for Name: domain_history; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY domain_history (historyid, zone, id, exdate, registrant, nsset, keyset) FROM stdin;
28	2	28	2016-06-14	6	8	18
29	2	29	2016-06-14	6	8	18
30	2	30	2016-06-14	6	8	18
31	2	31	2016-06-14	6	8	18
32	2	32	2016-06-14	6	8	18
33	2	33	2016-06-14	6	8	18
34	2	34	2016-06-14	6	8	18
35	2	35	2016-06-14	6	8	18
36	2	36	2016-06-14	6	8	18
37	2	37	2016-06-14	6	8	18
38	2	38	2016-06-14	4	8	18
39	2	39	2016-06-14	4	8	18
40	2	40	2016-06-14	4	8	18
41	2	41	2016-06-14	4	8	18
42	2	42	2016-06-14	4	8	18
43	2	43	2016-06-14	4	8	18
44	2	44	2016-06-14	4	8	18
45	2	45	2016-06-14	4	8	18
46	2	46	2016-06-14	4	8	18
47	2	47	2016-06-14	4	8	18
48	1	48	2014-06-14	6	8	18
49	1	49	2014-06-14	6	8	18
50	1	50	2014-06-14	6	8	18
51	1	51	2014-06-14	6	8	18
52	1	52	2014-06-14	6	8	18
53	1	53	2014-06-14	6	8	18
54	1	54	2014-06-14	6	8	18
55	1	55	2014-06-14	6	8	18
56	1	56	2014-06-14	6	8	18
57	1	57	2014-06-14	6	8	18
58	1	58	2014-06-14	6	8	18
\.


--
-- Data for Name: dsrecord; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY dsrecord (id, keysetid, keytag, alg, digesttype, digest, maxsiglife) FROM stdin;
\.


--
-- Data for Name: dsrecord_history; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY dsrecord_history (historyid, id, keysetid, keytag, alg, digesttype, digest, maxsiglife) FROM stdin;
\.


--
-- Data for Name: enum_bank_code; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY enum_bank_code (code, name_short, name_full) FROM stdin;
5400	AMRO	ABN AMRO BANK N.V.
2700	HVB	HVB CZECH REPUBLIC, A. S.
4000	BNP	BNP-DRESDNER BANK (ČR) A.S.
2600	CITI	CITIBANK A.S.
6200	COMM	COMMERZBANK AG
0800	CS	ČESKÁ SPOŘITELNA A.S.
2100	CMHB	ČESKOMOR. HYPOTÉČNÍ BANKA A.S.
7960	CMSS	ČESKOMORAVSKÁ STAVEBNÍ SPOŘITELNA
0300	CSOB	ČESKOSLOVENSKÁ OBCHODNÍ BANKA A.S.
7910	DB	DEUTSCHE BANK A.G.
2400	EB	EBANKA
0600	GE	GE CAPITAL BANK, A. S.
8070	HYPO	HYPO STAVEBNÍ SPOŘITELNA
6100	IC	IC BANKA A.S.
3500	ING	ING BANK N. V.
2500	INTB	INTERBANKA A.S.
5800	J&T	J & T BANKA, A. S.
0100	KB	KOMERČNÍ BANKA A.S.
3300	KONS	KONSOLIDAČNÍ BANKA PRAHA
4600	PILS	PLZEŇSKÁ BANKA A.S.
6000	PPF	PPF BANKA A.S.
7950	RFSS	RAIFFEISEN STAVEBNÍ SPOŘITELNA, A. S.
5500	RF	RAIFFEISENBANK A.S.
8060	SSCS	STAVEBNÍ SPOŘITELNA ČESKÉ SPOŘITELNY, A. S.
3400	UB	UNION BANKA A.S.
6800	VB	VOLKSBANK CZ, A. S.
6700	VUB	VŠEOB.ÚVĚR.BANKA POB. PRAHA
7990	VSS	VŠEOBECNÁ STAV.SPOŘITELNA
7970	WS	WUSTENROT STAVEBNÍ SPOŘITELNA
0400	ZB	ŽIVNOSTENSKÁ BANKA A.S.
2010	FIOZ	Fio, družstevní záložna
\.


--
-- Data for Name: enum_country; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY enum_country (id, country, country_cs) FROM stdin;
AF	Afghanistan	Afghánistán
AG	Antigua and Barbuda	Antigua a Barbuda
AI	Anguilla	Anguilla
AM	Armenia	Arménie
AO	Angola	Angola
AQ	Antarctica	Antarktika
AS	American Samoa	Americká Samoa
AT	Austria	Rakousko
AU	Australia	Austrálie
AX	Åland Islands	Alandské ostrovy
AZ	Azerbaijan	Ázerbájdžán
BB	Barbados	Barbados
BD	Bangladesh	Bangladéš
BE	Belgium	Belgie
BG	Bulgaria	Bulharsko
BH	Bahrain	Bahrajn
BI	Burundi	Burundi
BJ	Benin	Benin
BM	Bermuda	Bermudy
BN	Brunei Darussalam	Brunej Darussalam
BQ	Bonaire, Sint Eustatius and Saba	Bonaire, Svatý Eustach a Saba
BR	Brazil	Brazílie
BS	Bahamas	Bahamy
BT	Bhutan	Bhútán
BW	Botswana	Botswana
BY	Belarus	Bělorusko
BZ	Belize	Belize
CA	Canada	Kanada
CD	Congo, the Democratic Republic of the	Kongo, demokratická republika
CF	Central African Republic	Středoafrická republika
CG	Congo	Kongo, republika
CI	Côte d'Ivoire	Pobřeží slonoviny
CK	Cook Islands	Cookovy ostrovy
CM	Cameroon	Kamerun
CN	China	Čína
CO	Colombia	Kolumbie
CR	Costa Rica	Kostarika
CV	Cape Verde	Kapverdy
CW	Curaçao	Curaçao
CY	Cyprus	Kypr
CZ	Czech Republic	Česká republika
DE	Germany	Německo
DJ	Djibouti	Džibutsko
DM	Dominica	Dominika
DO	Dominican Republic	Dominikánská republika
EC	Ecuador	Ekvádor
EE	Estonia	Estonsko
EG	Egypt	Egypt
ER	Eritrea	Eritrea
ES	Spain	Španělsko
ET	Ethiopia	Etiopie
FI	Finland	Finsko
FJ	Fiji	Fidži
FM	Micronesia, Federated States of	Mikronésie, federativní státy
FO	Faroe Islands	Faerské ostrovy
GA	Gabon	Gabon
GB	United Kingdom	Spojené království
GD	Grenada	Grenada
GE	Georgia	Gruzie
GG	Guernsey	Guernsey
GH	Ghana	Ghana
GI	Gibraltar	Gibraltar
GL	Greenland	Grónsko
GN	Guinea	Guinea
GP	Guadeloupe	Guadeloupe
GR	Greece	Řecko
GT	Guatemala	Guatemala
GU	Guam	Guam
GW	Guinea-Bissau	Guinea-Bissau
GY	Guyana	Guyana
HK	Hong Kong	Hongkong
HN	Honduras	Honduras
HR	Croatia	Chorvatsko
HT	Haiti	Haiti
HU	Hungary	Maďarsko
ID	Indonesia	Indonésie
IE	Ireland	Irsko
IL	Israel	Izrael
IM	Isle of Man	Ostrov Man
IN	India	Indie
IQ	Iraq	Irák
IR	Iran, Islamic Republic of	Írán (islámská republika)
IS	Iceland	Island
IT	Italy	Itálie
JE	Jersey	Jersey
JO	Jordan	Jordánsko
JP	Japan	Japonsko
KE	Kenya	Keňa
KG	Kyrgyzstan	Kyrgyzstán
KI	Kiribati	Kiribati
KM	Comoros	Komory
KR	Korea, Republic of	Korejská republika
KW	Kuwait	Kuvajt
KY	Cayman Islands	Kajmanské ostrovy
KZ	Kazakhstan	Kazachstán
LB	Lebanon	Libanon
LC	Saint Lucia	Svatá Lucie
LI	Liechtenstein	Lichtenštejnsko
LK	Sri Lanka	Srí Lanka
LR	Liberia	Libérie
LS	Lesotho	Lesotho
LT	Lithuania	Litva
LU	Luxembourg	Lucembursko
LY	Libya	Libye
MA	Morocco	Maroko
MC	Monaco	Monako
ME	Montenegro	Černá Hora
MG	Madagascar	Madagaskar
MH	Marshall Islands	Marshallovy ostrovy
ML	Mali	Mali
MM	Myanmar	Myanmar
MN	Mongolia	Mongolsko
MO	Macao	Macao
MP	Northern Mariana Islands	Ostrovy Severní Mariany
MQ	Martinique	Martinik
MR	Mauritania	Mauritánie
MS	Montserrat	Montserrat
MT	Malta	Malta
AD	Andorra	Andorra
AE	United Arab Emirates	Spojené arabské emiráty
AL	Albania	Albánie
AR	Argentina	Argentina
AW	Aruba	Aruba
BA	Bosnia and Herzegovina	Bosna a Hercegovina
BF	Burkina Faso	Burkina Faso
BL	Saint Barthélemy	Svatý Bartoloměj
BO	Bolivia, Plurinational State of	Mnohonárodní stát Bolívie
BV	Bouvet Island	Bouvetův ostrov
CC	Cocos (Keeling) Islands	Kokosové (Keelingovy) ostrovy
CH	Switzerland	Švýcarsko
CL	Chile	Chile
CU	Cuba	Kuba
CX	Christmas Island	Vánoční ostrov
DK	Denmark	Dánsko
DZ	Algeria	Alžírsko
EH	Western Sahara	Západní Sahara
FK	Falkland Islands (Malvinas)	Falklandské ostrovy (Malvíny)
FR	France	Francie
GF	French Guiana	Francouzská Guyana
GM	Gambia	Gambie
GQ	Equatorial Guinea	Rovníková Guinea
GS	South Georgia and the South Sandwich Islands	Jižní Georgie a Jižní Sandwichovy ostrovy
HM	Heard Island and McDonald Islands	Heardův ostrov a McDonaldovy ostrovy
IO	British Indian Ocean Territory	Britské indickooceánské území
JM	Jamaica	Jamajka
KH	Cambodia	Kambodža
KN	Saint Kitts and Nevis	Svatý Kryštof a Nevis
KP	Korea, Democratic People's Republic of	Korea, lidově demokratická republika
LA	Lao People's Democratic Republic	Laoská lidově demokratická republika
LV	Latvia	Lotyšsko
MD	Moldova, Republic of	Moldavsko
MF	Saint Martin (French part)	Svatý Martin (francouzská část)
MK	Macedonia, the former Yugoslav Republic of	Makedonie, bývalá jugoslávská republika
MU	Mauritius	Mauricius
MV	Maldives	Maledivy
MW	Malawi	Malawi
MX	Mexico	Mexiko
MY	Malaysia	Malajsie
MZ	Mozambique	Mosambik
NA	Namibia	Namibie
NC	New Caledonia	Nová Kaledonie
NE	Niger	Niger
NF	Norfolk Island	Ostrov Norfolk
NG	Nigeria	Nigérie
NI	Nicaragua	Nikaragua
NL	Netherlands	Nizozemsko
NO	Norway	Norsko
NP	Nepal	Nepál
NR	Nauru	Nauru
NU	Niue	Niue
NZ	New Zealand	Nový Zéland
OM	Oman	Omán
PA	Panama	Panama
PE	Peru	Peru
PF	French Polynesia	Francouzská Polynésie
PG	Papua New Guinea	Papua Nová Guinea
PH	Philippines	Filipíny
PK	Pakistan	Pákistán
PL	Poland	Polsko
PM	Saint Pierre and Miquelon	Saint Pierre a Miquelon
PN	Pitcairn	Pitcairn
PR	Puerto Rico	Portoriko
PS	Palestinian Territory, Occupied	Palestinské území (okupované)
PT	Portugal	Portugalsko
PW	Palau	Palau
PY	Paraguay	Paraguay
QA	Qatar	Katar
RE	Réunion	Réunion
RO	Romania	Rumunsko
RS	Serbia	Srbsko
RU	Russian Federation	Ruská federace
RW	Rwanda	Rwanda
SA	Saudi Arabia	Saúdská Arábie
SB	Solomon Islands	Šalomounovy ostrovy
SC	Seychelles	Seychely
SD	Sudan	Súdán
SE	Sweden	Švédsko
SG	Singapore	Singapur
SH	Saint Helena, Ascension and Tristan da Cunha	Svatá Helena, Ascension a Tristan da Cunha
SI	Slovenia	Slovinsko
SJ	Svalbard and Jan Mayen	Svalbard a Jan Mayen
SK	Slovakia	Slovensko
SL	Sierra Leone	Sierra Leone
SM	San Marino	San Marino
SN	Senegal	Senegal
SO	Somalia	Somálsko
SR	Suriname	Surinam
SS	South Sudan	Jižní Súdán
ST	Sao Tome and Principe	Svatý Tomáš a Princův ostrov
SV	El Salvador	Salvador
SX	Sint Maarten (Dutch part)	Svatý Martin (nizozemská část)
SY	Syrian Arab Republic	Syrská arabská republika
SZ	Swaziland	Svazijsko
TC	Turks and Caicos Islands	Ostrovy Turks a Caicos
TD	Chad	Čad
TF	French Southern Territories	Francouzská jižní území
TG	Togo	Togo
TH	Thailand	Thajsko
TK	Tokelau	Tokelau
TL	Timor-Leste	Východní Timor
TM	Turkmenistan	Turkmenistán
TO	Tonga	Tonga
TR	Turkey	Turecko
TV	Tuvalu	Tuvalu
TW	Taiwan, Province of China	Tchaj-wan
UA	Ukraine	Ukrajina
UG	Uganda	Uganda
UM	United States Minor Outlying Islands	Menší odlehlé ostrovy USA
US	United States	Spojené státy
UY	Uruguay	Uruguay
VC	Saint Vincent and the Grenadines	Svatý Vincenc a Grenadiny
VE	Venezuela, Bolivarian Republic of	Bolívarovská republika Venezuela
VG	Virgin Islands, British	Britské Panenské ostrovy
VN	Viet Nam	Vietnam
VU	Vanuatu	Vanuatu
WF	Wallis and Futuna	Wallis a Futuna
WS	Samoa	Samoa
YE	Yemen	Jemen
YT	Mayotte	Mayotte
ZM	Zambia	Zambie
ZW	Zimbabwe	Zimbabwe
TJ	Tajikistan	Tádžikistán
TN	Tunisia	Tunisko
TT	Trinidad And Tobago	Trinidad a Tobago
TZ	Tanzania, United Republic of	Tanzanská sjednocená republika
UZ	Uzbekistan	Uzbekistán
VA	Holy See (Vatican City State)	Svatý stolec (Vatikánský městský stát)
VI	Virgin Islands, U.S.	Americké Panenské ostrovy
ZA	South Africa	Jižní Afrika
\.


--
-- Data for Name: enum_error; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY enum_error (id, status, status_cs) FROM stdin;
1000	Command completed successfully	Příkaz úspěšně proveden
1001	Command completed successfully; action pending	Příkaz úspěšně proveden; vykonání akce odloženo
1300	Command completed successfully; no messages	Příkaz úspěšně proveden; žádné nové zprávy
1301	Command completed successfully; ack to dequeue	Příkaz úspěšně proveden; potvrď za účelem vyřazení z fronty
1500	Command completed successfully; ending session	Příkaz úspěšně proveden; konec relace
2000	Unknown command	Neznámý příkaz
2001	Command syntax error	Chybná syntaxe příkazu
2002	Command use error	Chybné použití příkazu
2003	Required parameter missing	Požadovaný parametr neuveden
2004	Parameter value range error	Chybný rozsah parametru
2005	Parameter value syntax error	Chybná syntaxe hodnoty parametru
2100	Unimplemented protocol version	Neimplementovaná verze protokolu
2101	Unimplemented command	Neimplementovaný příkaz
2102	Unimplemented option	Neimplementovaná volba
2103	Unimplemented extension	Neimplementované rozšíření
2104	Billing failure	Účetní selhání
2105	Object is not eligible for renewal	Objekt je nezpůsobilý pro obnovení
2106	Object is not eligible for transfer	Objekt je nezpůsobilý pro transfer
2200	Authentication error	Chyba ověření identity
2201	Authorization error	Chyba oprávnění
2202	Invalid authorization information	Chybná autorizační informace
2300	Object pending transfer	Objekt čeká na transfer
2301	Object not pending transfer	Objekt nečeká na transfer
2302	Object exists	Objekt existuje
2303	Object does not exist	Objekt neexistuje
2304	Object status prohibits operation	Status objektu nedovoluje operaci
2305	Object association prohibits operation	Asociace objektu nedovoluje operaci
2306	Parameter value policy error	Chyba zásady pro hodnotu parametru
2307	Unimplemented object service	Neimplementovaná služba objektu
2308	Data management policy violation	Porušení zásady pro správu dat
2400	Command failed	Příkaz selhal
2500	Command failed; server closing connection	Příkaz selhal; server uzavírá spojení
2501	Authentication error; server closing connection	Chyba ověření identity; server uzavírá spojení
2502	Session limit exceeded; server closing connection	Limit na počet relací překročen; server uzavírá spojení
\.


--
-- Data for Name: enum_filetype; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY enum_filetype (id, name) FROM stdin;
1	invoice pdf
2	invoice xml
3	accounting xml
4	banking statement
5	expiration warning letter
6	certification evaluation pdf
7	mojeid contact identification request
\.


--
-- Data for Name: enum_object_states; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY enum_object_states (id, name, types, manual, external, importance) FROM stdin;
2	serverRenewProhibited	{3}	t	t	28
5	serverOutzoneManual	{3}	t	t	14
6	serverInzoneManual	{3}	t	t	16
7	serverBlocked	{3}	t	t	32
8	expirationWarning	{3}	f	f	\N
9	expired	{3}	f	t	2
10	unguarded	{3}	f	f	\N
11	validationWarning1	{3}	f	f	\N
12	validationWarning2	{3}	f	f	\N
13	notValidated	{3}	f	t	18
14	nssetMissing	{3}	f	f	\N
15	outzone	{3}	f	t	6
18	serverRegistrantChangeProhibited	{3}	t	t	26
19	deleteWarning	{3}	f	f	\N
20	outzoneUnguarded	{3}	f	f	\N
1	serverDeleteProhibited	{1,2,3,4}	t	t	30
3	serverTransferProhibited	{1,2,3,4}	t	t	24
4	serverUpdateProhibited	{1,2,3,4}	t	t	22
16	linked	{1,2,4}	f	t	20
17	deleteCandidate	{1,2,3,4}	f	t	\N
21	conditionallyIdentifiedContact	{1}	t	t	10
22	identifiedContact	{1}	t	t	8
23	validatedContact	{1}	t	t	12
24	mojeidContact	{1}	t	t	4
\.


--
-- Data for Name: enum_object_states_desc; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY enum_object_states_desc (state_id, lang, description) FROM stdin;
1	CS	Není povoleno smazání
1	EN	Deletion unauthorised
2	CS	Není povoleno prodloužení registrace objektu
2	EN	Registration renewal unauthorised
3	CS	Není povolena změna určeného registrátora
3	EN	Sponsoring registrar change unauthorised
4	CS	Není povolena změna údajů
4	EN	Update unauthorised
5	CS	Doména je administrativně vyřazena ze zóny
5	EN	The domain is administratively kept out of zone
6	CS	Doména je administrativně zařazena do zóny
6	EN	The domain is administratively kept in zone
7	CS	Doména je blokována
7	EN	Domain blocked
8	CS	Doména expiruje do 30 dní
8	EN	The domain expires in 30 days
9	CS	Doména je po expiraci
9	EN	Domain expired
10	CS	Doména je 30 dnů po expiraci
10	EN	The domain is 30 days after expiration
11	CS	Validace domény skončí za 30 dní
11	EN	The domain validation expires in 30 days
12	CS	Validace domény skončí za 15 dní
12	EN	The domain validation expires in 15 days
13	CS	Doména není validována
13	EN	Domain not validated
14	CS	Doména nemá přiřazen nsset
14	EN	The domain doesn't have associated nsset
15	CS	Doména není generována do zóny
15	EN	The domain isn't generated in the zone
16	CS	Je navázán na další záznam v registru
16	EN	Has relation to other records in the registry
17	CS	Určeno ke zrušení
17	EN	To be deleted
18	CS	Není povolena změna držitele
18	EN	Registrant change unauthorised
19	CS	Registrace domény bude zrušena za 11 dní
19	EN	The domain will be deleted in 11 days
20	CS	Doména vyřazena ze zóny po 30 dnech od expirace
20	EN	The domain is out of zone after 30 days in expiration state
21	CS	Kontakt je částečně identifikován
21	EN	Contact is conditionally identified
22	CS	Kontakt je identifikován
22	EN	Contact is identified
23	CS	Kontakt je validován
23	EN	Contact is validated
24	CS	MojeID kontakt
24	EN	MojeID contact
\.


--
-- Data for Name: enum_operation; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY enum_operation (id, operation) FROM stdin;
1	CreateDomain
2	RenewDomain
4	Fine
5	Fee
3	GeneralEppOperation
\.


--
-- Data for Name: enum_parameters; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY enum_parameters (id, name, val) FROM stdin;
2	tld_list_version	2008013001
3	expiration_notify_period	-30
4	expiration_dns_protection_period	30
5	expiration_letter_warning_period	34
6	expiration_registration_protection_period	61
7	validation_notify1_period	-30
8	validation_notify2_period	-15
9	regular_day_procedure_period	0
10	regular_day_procedure_zone	Europe/Prague
11	object_registration_protection_period	6
14	regular_day_outzone_procedure_period	14
1	model_version	<insert version here>
12	handle_registration_protection_period	2
13	roid_suffix	CZ
\.


--
-- Data for Name: enum_public_request_status; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY enum_public_request_status (id, name, description) FROM stdin;
0	new	New
1	answered	Answered
2	invalidated	Invalidated
\.


--
-- Data for Name: enum_public_request_type; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY enum_public_request_type (id, name, description) FROM stdin;
0	authinfo_auto_rif	AuthInfo (EPP/Auto)
1	authinfo_auto_pif	AuthInfo (Web/Auto)
2	authinfo_email_pif	AuthInfo (Web/Email)
3	authinfo_post_pif	AuthInfo (Web/Post)
4	block_changes_email_pif	Block changes (Web/Email)
5	block_changes_post_pif	Block changes (Web/Post)
6	block_transfer_email_pif	Block transfer (Web/Email)
7	block_transfer_post_pif	Block transfer (Web/Post)
8	unblock_changes_email_pif	Unblock changes (Web/Email)
9	unblock_changes_post_pif	Unblock changes (Web/Post)
10	unblock_transfer_email_pif	Unblock transfer (Web/Email)
11	unblock_transfer_post_pif	Unblock transfer (Web/Post)
12	mojeid_contact_conditional_identification	MojeID conditional identification
13	mojeid_contact_identification	MojeID full identification
14	mojeid_contact_validation	MojeID validation
17	mojeid_conditionally_identified_contact_transfer	MojeID conditionally identified contact transfer
18	mojeid_identified_contact_transfer	MojeID identified contact transfer
15	contact_conditional_identification	Conditional identification
16	contact_identification	Full identification
\.


--
-- Data for Name: enum_reason; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY enum_reason (id, reason, reason_cs) FROM stdin;
1	bad format of contact handle	neplatný formát ukazatele kontaktu
2	bad format of nsset handle	neplatný formát ukazatele nssetu
3	bad format of fqdn domain	neplatný formát názvu domény
4	Domain name not applicable.	nepoužitelný název domény
5	invalid format	neplatný formát
6	already registered.	již zaregistrováno
7	within protection period.	je v ochranné lhůtě
8	Invalid IP address.	neplatná IP adresa
9	Invalid nameserver hostname.	neplatný formát názvu jmenného serveru DNS
10	Duplicate nameserver address.	duplicitní adresa jmenného serveru DNS
11	Glue IP address not allowed here.	nepovolená  IP adresa glue záznamu
12	At least two nameservers required.	jsou zapotřebí alespoň dva DNS servery
13	invalid date of period	neplatná hodnota periody
14	period exceedes maximal allowed validity time.	perioda je nad maximální dovolenou hodnotou
15	period is not aligned with allowed step.	perioda neodpovídá dovolenému intervalu
16	Unknown country code	neznámý kód země
17	Unknown message ID	neznámé msgID
18	Validation expiration date can not be used here.	datum vypršení platnosti se nepoužívá
19	Validation expiration date does not match registry data.	datum vypršení platnosti je neplatné
20	Validation expiration date is required.	datum vypršení platnosti je požadováno
21	Can not remove nameserver.	nelze odstranit jmenný server DNS
22	Can not add nameserver	nelze přidat jmenný server DNS
23	Can not remove technical contact	nelze vymazat technický kontakt
24	Technical contact is already assigned to this object.	Technický kontakt je již přiřazen k tomuto objektu
25	Technical contact does not exist	Technický kontakt neexistuje
26	Administrative contact is already assigned to this object.	Administrátorský kontakt je již přiřazen k tomuto objektu
27	Administrative contact does not exist	Administrátorský kontakt neexistuje
28	nsset handle does not exist.	sada jmenných serverů není vytvořena
29	contact handle of registrant does not exist.	ukazatel kontaktu vlastníka není vytvořen
30	Nameserver is already set to this nsset.	jmenný server DNS je již přiřazen sadě jmenných serverů
31	Nameserver is not set to this nsset.	jmenný server DNS není přiřazen sadě jmenných serverů
32	Expiration date does not match registry data.	Nesouhlasí datum expirace
33	Attribute op in element transfer is missing	Chybí atribut op u elementu transfer
34	Attribute type in element ident is missing	Chybí atribut type u elementu ident
35	Attribute msgID in element poll is missing	Chybí atribut msgID u elementu poll
36	Registration is prohibited	Registrace je zakázána
37	Schemas validity error: 	Chyba validace XML schemat:
38	Duplicity contact	Duplicitní kontakt
39	Bad format of keyset handle	Neplatný formát ukazatele keysetu
40	Keyset handle does not exist	Ukazatel keysetu není vytvořen
41	DSRecord does not exists	DSRecord záznam neexistuje
42	Can not remove DSRecord	Nelze odstranit DSRecord záznam
43	Duplicity DSRecord	Duplicitní DSRecord záznam
44	DSRecord already exists for this keyset	DSRecord již pro tento keyset existuje
45	DSRecord is not set for this keyset	DSRecord pro tento keyset neexistuje
46	Field ``digest type'' must be 1 (SHA-1)	Pole ``digest type'' musí být 1 (SHA-1)
47	Digest must be 40 characters long	Digest musí být dlouhý 40 znaků
48	Object does not belong to the registrar	Objekt nepatří registrátorovi
49	Too many technical administrators contacts.	Příliš mnoho administrátorských kontaktů
50	Too many DS records	Příliš mnoho DS záznamů
51	Too many DNSKEY records	Příliš mnoho DNSKEY záznamů
52	Too many nameservers in this nsset	Příliš mnoho jmenných serverů DNS je přiřazeno sadě jmenných serverů
53	No DNSKey record	Žádný DNSKey záznam
54	Field ``flags'' must be 0, 256 or 257	Pole ``flags'' musí být 0, 256 nebo 257
55	Field ``protocol'' must be 3	Pole ``protocol'' musí být 3
56	Field ``alg'' must be 1,2,3,4,5,6,7,8,10,12,252,253,254 or 255	Pole ``alg'' musí být 1,2,3,4,5,6,7,8,10,12,252,253,254 nebo 255
57	Field ``key'' has invalid length	Pole ``key'' má špatnou délku
58	Field ``key'' contains invalid character	Pole ``key'' obsahuje neplatný znak
59	DNSKey already exists for this keyset	DNSKey již pro tento keyset existuje
60	DNSKey does not exist for this keyset	DNSKey pro tento keyset neexistuje
61	Duplicity DNSKey	Duplicitní DNSKey
62	Keyset must have DNSKey or DSRecord	Keyset musí mít DNSKey nebo DSRecord
\.


--
-- Data for Name: enum_send_status; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY enum_send_status (id, status_name, description) FROM stdin;
1	ready	Ready for processing/sending
2	waiting_confirmation	Waiting for manual confirmation of sending
3	no_processing	No automatic processing
4	send_failed	Delivery failed
5	sent	Successfully sent
6	being_sent	In processing, don't touch
\.


--
-- Data for Name: enum_ssntype; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY enum_ssntype (id, type, description) FROM stdin;
1	RC	born number
2	OP	identity card number
3	PASS	passwport
4	ICO	organization identification number
5	MPSV	social system identification
6	BIRTHDAY	day of birth
\.


--
-- Data for Name: enum_tlds; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY enum_tlds (tld) FROM stdin;
AC
AD
AE
AERO
AF
AG
AI
AL
AM
AN
AO
AQ
AR
ARPA
AS
ASIA
AT
AU
AW
AX
AZ
BA
BB
BD
BE
BF
BG
BH
BI
BIZ
BJ
BM
BN
BO
BR
BS
BT
BV
BW
BY
BZ
CA
CAT
CC
CD
CF
CG
CH
CI
CK
CL
CM
CN
CO
COM
COOP
CR
CU
CV
CX
CY
CZ
DE
DJ
DK
DM
DO
DZ
EC
EDU
EE
EG
ER
ES
ET
EU
FI
FJ
FK
FM
FO
FR
GA
GB
GD
GE
GF
GG
GH
GI
GL
GM
GN
GOV
GP
GQ
GR
GS
GT
GU
GW
GY
HK
HM
HN
HR
HT
HU
ID
IE
IL
IM
IN
INFO
INT
IO
IQ
IR
IS
IT
JE
JM
JO
JOBS
JP
KE
KG
KH
KI
KM
KN
KP
KR
KW
KY
KZ
LA
LB
LC
LI
LK
LR
LS
LT
LU
LV
LY
MA
MC
MD
ME
MG
MH
MIL
MK
ML
MM
MN
MO
MOBI
MP
MQ
MR
MS
MT
MU
MUSEUM
MV
MW
MX
MY
MZ
NA
NAME
NC
NE
NET
NF
NG
NI
NL
NO
NP
NR
NU
NZ
OM
ORG
PA
PE
PF
PG
PH
PK
PL
PM
PN
PR
PRO
PS
PT
PW
PY
QA
RE
RO
RS
RU
RW
SA
SB
SC
SD
SE
SG
SH
SI
SJ
SK
SL
SM
SN
SO
SR
ST
SU
SV
SY
SZ
TC
TD
TEL
TF
TG
TH
TJ
TK
TL
TM
TN
TO
TP
TR
TRAVEL
TT
TV
TW
TZ
UA
UG
UK
UM
US
UY
UZ
VA
VC
VE
VG
VI
VN
VU
WF
WS
XN--0ZWM56D
XN--11B5BS3A9AJ6G
XN--80AKHBYKNJ4F
XN--9T4B11YI5A
XN--DEBA0AD
XN--G6W251D
XN--HGBK6AJ7F53BBA
XN--HLCJ6AYA9ESC7A
XN--JXALPDLP
XN--KGBECHTV
XN--ZCKZAH
YE
YT
YU
ZA
ZM
ZW
\.


--
-- Data for Name: enumval; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY enumval (domainid, exdate, publish) FROM stdin;
48	2013-11-14	f
49	2013-11-14	f
50	2013-11-14	f
51	2013-11-14	f
52	2013-11-14	f
53	2013-11-14	f
54	2013-11-14	f
55	2013-11-14	f
56	2013-11-14	f
57	2013-11-14	f
58	2013-11-14	f
\.


--
-- Data for Name: enumval_history; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY enumval_history (historyid, domainid, exdate, publish) FROM stdin;
48	48	2013-11-14	f
49	49	2013-11-14	f
50	50	2013-11-14	f
51	51	2013-11-14	f
52	52	2013-11-14	f
53	53	2013-11-14	f
54	54	2013-11-14	f
55	55	2013-11-14	f
56	56	2013-11-14	f
57	57	2013-11-14	f
58	58	2013-11-14	f
\.


--
-- Data for Name: epp_info_buffer; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY epp_info_buffer (registrar_id, current) FROM stdin;
\.


--
-- Data for Name: epp_info_buffer_content; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY epp_info_buffer_content (id, registrar_id, object_id) FROM stdin;
\.


--
-- Data for Name: files; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY files (id, name, path, mimetype, crdate, filesize, filetype) FROM stdin;
1	test.txt	2013/6/14/1	text/plain	2013-06-14 13:29:05.284977	5	6
2	example_payments.xml	2013/6/14/2	text/xml	2013-06-14 13:29:05.771362	4881	4
3	example_payments.xml	2013/6/14/3	text/xml	2013-06-14 13:29:05.798312	4881	4
4	example_payments.xml	2013/6/14/4	text/xml	2013-06-14 13:29:05.824348	4881	4
5	example_payments.xml	2013/6/14/5	text/xml	2013-06-14 13:29:05.850294	4881	4
6	example_payments.xml	2013/6/14/6	text/xml	2013-06-14 13:29:05.876639	4881	4
7	example_payments.xml	2013/6/14/7	text/xml	2013-06-14 13:29:05.903328	4881	4
\.


--
-- Data for Name: filters; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY filters (id, type, name, userid, groupid, data) FROM stdin;
\.


--
-- Data for Name: genzone_domain_history; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY genzone_domain_history (id, domain_id, domain_hid, zone_id, status, inzone, chdate, last) FROM stdin;
\.


--
-- Data for Name: genzone_domain_status; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY genzone_domain_status (id, name) FROM stdin;
1	is in zone
2	is deleted
3	is without nsset
4	expired
5	is not validated
\.


--
-- Data for Name: history; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY history (id, valid_from, valid_to, next, request_id) FROM stdin;
1	2013-06-14 13:31:49.507845	\N	\N	2
2	2013-06-14 13:31:49.804755	\N	\N	5
3	2013-06-14 13:31:50.0992	\N	\N	8
4	2013-06-14 13:31:50.396431	\N	\N	11
5	2013-06-14 13:31:50.698085	\N	\N	14
6	2013-06-14 13:31:50.991574	\N	\N	17
7	2013-06-14 13:31:51.297114	\N	\N	20
8	2013-06-14 13:31:51.700438	\N	\N	23
9	2013-06-14 13:31:51.989028	\N	\N	26
10	2013-06-14 13:31:52.283892	\N	\N	29
11	2013-06-14 13:31:52.570606	\N	\N	32
12	2013-06-14 13:31:52.859109	\N	\N	35
13	2013-06-14 13:31:53.147946	\N	\N	38
14	2013-06-14 13:31:53.443404	\N	\N	41
15	2013-06-14 13:31:53.737638	\N	\N	44
16	2013-06-14 13:31:54.034925	\N	\N	47
17	2013-06-14 13:31:54.324049	\N	\N	50
18	2013-06-14 13:31:54.616493	\N	\N	53
19	2013-06-14 13:31:54.888446	\N	\N	56
20	2013-06-14 13:31:55.159982	\N	\N	59
21	2013-06-14 13:31:55.438237	\N	\N	62
22	2013-06-14 13:31:55.721359	\N	\N	65
23	2013-06-14 13:31:56.001341	\N	\N	68
24	2013-06-14 13:31:56.276888	\N	\N	71
25	2013-06-14 13:31:56.558064	\N	\N	74
26	2013-06-14 13:31:56.840544	\N	\N	77
27	2013-06-14 13:31:57.124301	\N	\N	80
28	2013-06-14 13:31:57.394957	\N	\N	83
29	2013-06-14 13:31:57.701656	\N	\N	86
30	2013-06-14 13:31:58.0167	\N	\N	89
31	2013-06-14 13:31:58.33586	\N	\N	92
32	2013-06-14 13:31:58.648892	\N	\N	95
33	2013-06-14 13:31:58.954564	\N	\N	98
34	2013-06-14 13:31:59.265097	\N	\N	101
35	2013-06-14 13:31:59.574756	\N	\N	104
36	2013-06-14 13:31:59.885763	\N	\N	107
37	2013-06-14 13:32:00.190703	\N	\N	110
38	2013-06-14 13:32:00.496137	\N	\N	113
39	2013-06-14 13:32:00.795744	\N	\N	116
40	2013-06-14 13:32:01.101111	\N	\N	119
41	2013-06-14 13:32:01.413862	\N	\N	122
42	2013-06-14 13:32:01.723489	\N	\N	125
43	2013-06-14 13:32:02.043755	\N	\N	128
44	2013-06-14 13:32:02.3474	\N	\N	131
45	2013-06-14 13:32:02.65207	\N	\N	134
46	2013-06-14 13:32:02.954036	\N	\N	137
47	2013-06-14 13:32:03.249372	\N	\N	140
48	2013-06-14 13:32:03.556195	\N	\N	143
49	2013-06-14 13:32:03.871668	\N	\N	146
50	2013-06-14 13:32:04.191737	\N	\N	149
51	2013-06-14 13:32:04.509135	\N	\N	152
52	2013-06-14 13:32:04.825451	\N	\N	155
53	2013-06-14 13:32:05.143058	\N	\N	158
54	2013-06-14 13:32:05.464421	\N	\N	161
55	2013-06-14 13:32:05.773889	\N	\N	164
56	2013-06-14 13:32:06.084387	\N	\N	167
57	2013-06-14 13:32:06.391219	\N	\N	170
58	2013-06-14 13:32:06.702794	\N	\N	173
\.


--
-- Data for Name: host; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY host (id, nssetid, fqdn) FROM stdin;
1	8	ns1.domain.cz
2	8	ns2.domain.cz
3	9	ns1.domain.cz
4	9	ns2.domain.cz
5	10	ns1.domain.cz
6	10	ns2.domain.cz
7	11	ns1.domain.cz
8	11	ns2.domain.cz
9	12	ns1.domain.cz
10	12	ns2.domain.cz
11	13	ns1.domain.cz
12	13	ns2.domain.cz
13	14	ns1.domain.cz
14	14	ns2.domain.cz
15	15	ns1.domain.cz
16	15	ns2.domain.cz
17	16	ns1.domain.cz
18	16	ns2.domain.cz
19	17	ns1.domain.cz
20	17	ns2.domain.cz
\.


--
-- Data for Name: host_history; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY host_history (historyid, id, nssetid, fqdn) FROM stdin;
8	2	8	ns2.domain.cz
8	1	8	ns1.domain.cz
9	4	9	ns2.domain.cz
9	3	9	ns1.domain.cz
10	6	10	ns2.domain.cz
10	5	10	ns1.domain.cz
11	8	11	ns2.domain.cz
11	7	11	ns1.domain.cz
12	10	12	ns2.domain.cz
12	9	12	ns1.domain.cz
13	12	13	ns2.domain.cz
13	11	13	ns1.domain.cz
14	14	14	ns2.domain.cz
14	13	14	ns1.domain.cz
15	16	15	ns2.domain.cz
15	15	15	ns1.domain.cz
16	18	16	ns2.domain.cz
16	17	16	ns1.domain.cz
17	20	17	ns2.domain.cz
17	19	17	ns1.domain.cz
\.


--
-- Data for Name: host_ipaddr_map; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY host_ipaddr_map (id, hostid, nssetid, ipaddr) FROM stdin;
1	1	8	217.31.207.130
2	1	8	217.31.207.129
3	2	8	217.31.206.130
4	2	8	217.31.206.129
5	3	9	217.31.207.130
6	3	9	217.31.207.129
7	4	9	217.31.206.130
8	4	9	217.31.206.129
9	5	10	217.31.207.130
10	5	10	217.31.207.129
11	6	10	217.31.206.130
12	6	10	217.31.206.129
13	7	11	217.31.207.130
14	7	11	217.31.207.129
15	8	11	217.31.206.130
16	8	11	217.31.206.129
17	9	12	217.31.207.130
18	9	12	217.31.207.129
19	10	12	217.31.206.130
20	10	12	217.31.206.129
21	11	13	217.31.207.130
22	11	13	217.31.207.129
23	12	13	217.31.206.130
24	12	13	217.31.206.129
25	13	14	217.31.207.130
26	13	14	217.31.207.129
27	14	14	217.31.206.130
28	14	14	217.31.206.129
29	15	15	217.31.207.130
30	15	15	217.31.207.129
31	16	15	217.31.206.130
32	16	15	217.31.206.129
33	17	16	217.31.207.130
34	17	16	217.31.207.129
35	18	16	217.31.206.130
36	18	16	217.31.206.129
37	19	17	217.31.207.130
38	19	17	217.31.207.129
39	20	17	217.31.206.130
40	20	17	217.31.206.129
\.


--
-- Data for Name: host_ipaddr_map_history; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY host_ipaddr_map_history (historyid, id, hostid, nssetid, ipaddr) FROM stdin;
8	1	1	8	217.31.207.130
8	2	1	8	217.31.207.129
8	3	2	8	217.31.206.130
8	4	2	8	217.31.206.129
9	5	3	9	217.31.207.130
9	6	3	9	217.31.207.129
9	7	4	9	217.31.206.130
9	8	4	9	217.31.206.129
10	9	5	10	217.31.207.130
10	10	5	10	217.31.207.129
10	11	6	10	217.31.206.130
10	12	6	10	217.31.206.129
11	13	7	11	217.31.207.130
11	14	7	11	217.31.207.129
11	15	8	11	217.31.206.130
11	16	8	11	217.31.206.129
12	17	9	12	217.31.207.130
12	18	9	12	217.31.207.129
12	19	10	12	217.31.206.130
12	20	10	12	217.31.206.129
13	21	11	13	217.31.207.130
13	22	11	13	217.31.207.129
13	23	12	13	217.31.206.130
13	24	12	13	217.31.206.129
14	25	13	14	217.31.207.130
14	26	13	14	217.31.207.129
14	27	14	14	217.31.206.130
14	28	14	14	217.31.206.129
15	29	15	15	217.31.207.130
15	30	15	15	217.31.207.129
15	31	16	15	217.31.206.130
15	32	16	15	217.31.206.129
16	33	17	16	217.31.207.130
16	34	17	16	217.31.207.129
16	35	18	16	217.31.206.130
16	36	18	16	217.31.206.129
17	37	19	17	217.31.207.130
17	38	19	17	217.31.207.129
17	39	20	17	217.31.206.130
17	40	20	17	217.31.206.129
\.


--
-- Data for Name: invoice; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY invoice (id, zone_id, crdate, taxdate, prefix, registrar_id, balance, operations_price, vat, total, totalvat, invoice_prefix_id, file, filexml) FROM stdin;
1	1	2013-06-14 13:29:03.716302	2013-06-14	111300001	1	102875.88	\N	20	102875.88	20580.12	1	\N	\N
2	1	2013-06-14 13:29:03.756309	2013-06-14	111300002	2	510267.09	\N	20	510267.09	102077.91	1	\N	\N
3	1	2013-06-14 13:29:03.795527	2013-06-14	111300003	3	467676.29	\N	20	467676.29	93557.71	1	\N	\N
4	2	2013-06-14 13:29:03.827489	2013-06-14	241300001	1	380087.30	\N	20	380087.30	76035.70	3	\N	\N
5	2	2013-06-14 13:29:03.857824	2013-06-14	241300002	2	287998.48	\N	20	287998.48	57613.52	3	\N	\N
6	2	2013-06-14 13:29:03.897535	2013-06-14	241300003	3	195459.68	\N	20	195459.68	39101.32	3	\N	\N
7	2	2013-06-14 13:29:05.757872	2013-06-14	241300004	1	833.30	\N	20	833.30	166.70	3	\N	\N
8	2	2013-06-14 13:29:05.789327	2013-06-14	241300005	2	833.30	\N	20	833.30	166.70	3	\N	\N
9	1	2013-06-14 13:29:05.815849	2013-06-14	111300004	1	833.30	\N	20	833.30	166.70	1	\N	\N
10	1	2013-06-14 13:29:05.841804	2013-06-14	111300005	2	833.30	\N	20	833.30	166.70	1	\N	\N
11	2	2013-06-14 13:29:05.867756	2013-06-14	241300006	2	833.30	\N	20	833.30	166.70	3	\N	\N
12	2	2013-06-14 13:29:05.894756	2013-06-14	241300007	2	833.30	\N	20	833.30	166.70	3	\N	\N
\.


--
-- Data for Name: invoice_credit_payment_map; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY invoice_credit_payment_map (ac_invoice_id, ad_invoice_id, credit, balance) FROM stdin;
\.


--
-- Data for Name: invoice_generation; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY invoice_generation (id, fromdate, todate, registrar_id, zone_id, invoice_id) FROM stdin;
\.


--
-- Data for Name: invoice_mails; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY invoice_mails (id, invoiceid, genid, mailid) FROM stdin;
\.


--
-- Data for Name: invoice_number_prefix; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY invoice_number_prefix (id, prefix, zone_id, invoice_type_id) FROM stdin;
1	24	2	0
2	23	2	1
3	11	1	0
4	12	1	1
\.


--
-- Data for Name: invoice_operation; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY invoice_operation (id, ac_invoice_id, crdate, object_id, zone_id, registrar_id, operation_id, date_from, date_to, quantity, registrar_credit_transaction_id) FROM stdin;
1	\N	2013-06-14 13:31:57.425905	28	2	1	1	2013-06-14	\N	1	13
2	\N	2013-06-14 13:31:57.433499	28	2	1	2	2013-06-14	2016-06-14	3	14
3	\N	2013-06-14 13:31:57.730488	29	2	1	1	2013-06-14	\N	1	15
4	\N	2013-06-14 13:31:57.737759	29	2	1	2	2013-06-14	2016-06-14	3	16
5	\N	2013-06-14 13:31:58.045572	30	2	1	1	2013-06-14	\N	1	17
6	\N	2013-06-14 13:31:58.052904	30	2	1	2	2013-06-14	2016-06-14	3	18
7	\N	2013-06-14 13:31:58.36481	31	2	1	1	2013-06-14	\N	1	19
8	\N	2013-06-14 13:31:58.372135	31	2	1	2	2013-06-14	2016-06-14	3	20
9	\N	2013-06-14 13:31:58.677782	32	2	1	1	2013-06-14	\N	1	21
10	\N	2013-06-14 13:31:58.685116	32	2	1	2	2013-06-14	2016-06-14	3	22
11	\N	2013-06-14 13:31:58.984502	33	2	1	1	2013-06-14	\N	1	23
12	\N	2013-06-14 13:31:58.991852	33	2	1	2	2013-06-14	2016-06-14	3	24
13	\N	2013-06-14 13:31:59.293986	34	2	1	1	2013-06-14	\N	1	25
14	\N	2013-06-14 13:31:59.301291	34	2	1	2	2013-06-14	2016-06-14	3	26
15	\N	2013-06-14 13:31:59.603612	35	2	1	1	2013-06-14	\N	1	27
16	\N	2013-06-14 13:31:59.610904	35	2	1	2	2013-06-14	2016-06-14	3	28
17	\N	2013-06-14 13:31:59.914827	36	2	1	1	2013-06-14	\N	1	29
18	\N	2013-06-14 13:31:59.922141	36	2	1	2	2013-06-14	2016-06-14	3	30
19	\N	2013-06-14 13:32:00.219682	37	2	1	1	2013-06-14	\N	1	31
20	\N	2013-06-14 13:32:00.227015	37	2	1	2	2013-06-14	2016-06-14	3	32
21	\N	2013-06-14 13:32:00.523784	38	2	1	1	2013-06-14	\N	1	33
22	\N	2013-06-14 13:32:00.531074	38	2	1	2	2013-06-14	2016-06-14	3	34
23	\N	2013-06-14 13:32:00.823818	39	2	1	1	2013-06-14	\N	1	35
24	\N	2013-06-14 13:32:00.831187	39	2	1	2	2013-06-14	2016-06-14	3	36
25	\N	2013-06-14 13:32:01.128845	40	2	1	1	2013-06-14	\N	1	37
26	\N	2013-06-14 13:32:01.136165	40	2	1	2	2013-06-14	2016-06-14	3	38
27	\N	2013-06-14 13:32:01.441591	41	2	1	1	2013-06-14	\N	1	39
28	\N	2013-06-14 13:32:01.448876	41	2	1	2	2013-06-14	2016-06-14	3	40
29	\N	2013-06-14 13:32:01.751197	42	2	1	1	2013-06-14	\N	1	41
30	\N	2013-06-14 13:32:01.758486	42	2	1	2	2013-06-14	2016-06-14	3	42
31	\N	2013-06-14 13:32:02.071569	43	2	1	1	2013-06-14	\N	1	43
32	\N	2013-06-14 13:32:02.078839	43	2	1	2	2013-06-14	2016-06-14	3	44
33	\N	2013-06-14 13:32:02.375102	44	2	1	1	2013-06-14	\N	1	45
34	\N	2013-06-14 13:32:02.382401	44	2	1	2	2013-06-14	2016-06-14	3	46
35	\N	2013-06-14 13:32:02.679602	45	2	1	1	2013-06-14	\N	1	47
36	\N	2013-06-14 13:32:02.686919	45	2	1	2	2013-06-14	2016-06-14	3	48
37	\N	2013-06-14 13:32:02.981784	46	2	1	1	2013-06-14	\N	1	49
38	\N	2013-06-14 13:32:02.989061	46	2	1	2	2013-06-14	2016-06-14	3	50
39	\N	2013-06-14 13:32:03.27711	47	2	1	1	2013-06-14	\N	1	51
40	\N	2013-06-14 13:32:03.284426	47	2	1	2	2013-06-14	2016-06-14	3	52
41	\N	2013-06-14 13:32:03.588644	48	1	1	1	2013-06-14	\N	1	53
42	\N	2013-06-14 13:32:03.595955	48	1	1	2	2013-06-14	2014-06-14	1	54
43	\N	2013-06-14 13:32:03.902855	49	1	1	1	2013-06-14	\N	1	55
44	\N	2013-06-14 13:32:03.910146	49	1	1	2	2013-06-14	2014-06-14	1	56
45	\N	2013-06-14 13:32:04.222952	50	1	1	1	2013-06-14	\N	1	57
46	\N	2013-06-14 13:32:04.230226	50	1	1	2	2013-06-14	2014-06-14	1	58
47	\N	2013-06-14 13:32:04.540247	51	1	1	1	2013-06-14	\N	1	59
48	\N	2013-06-14 13:32:04.547524	51	1	1	2	2013-06-14	2014-06-14	1	60
49	\N	2013-06-14 13:32:04.85668	52	1	1	1	2013-06-14	\N	1	61
50	\N	2013-06-14 13:32:04.863999	52	1	1	2	2013-06-14	2014-06-14	1	62
51	\N	2013-06-14 13:32:05.174218	53	1	1	1	2013-06-14	\N	1	63
52	\N	2013-06-14 13:32:05.181527	53	1	1	2	2013-06-14	2014-06-14	1	64
53	\N	2013-06-14 13:32:05.495885	54	1	1	1	2013-06-14	\N	1	65
54	\N	2013-06-14 13:32:05.503196	54	1	1	2	2013-06-14	2014-06-14	1	66
55	\N	2013-06-14 13:32:05.805132	55	1	1	1	2013-06-14	\N	1	67
56	\N	2013-06-14 13:32:05.812431	55	1	1	2	2013-06-14	2014-06-14	1	68
57	\N	2013-06-14 13:32:06.115504	56	1	1	1	2013-06-14	\N	1	69
58	\N	2013-06-14 13:32:06.122767	56	1	1	2	2013-06-14	2014-06-14	1	70
59	\N	2013-06-14 13:32:06.422505	57	1	1	1	2013-06-14	\N	1	71
60	\N	2013-06-14 13:32:06.429955	57	1	1	2	2013-06-14	2014-06-14	1	72
61	\N	2013-06-14 13:32:06.734003	58	1	1	1	2013-06-14	\N	1	73
62	\N	2013-06-14 13:32:06.741376	58	1	1	2	2013-06-14	2014-06-14	1	74
\.


--
-- Data for Name: invoice_operation_charge_map; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY invoice_operation_charge_map (invoice_operation_id, invoice_id, price) FROM stdin;
\.


--
-- Data for Name: invoice_prefix; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY invoice_prefix (id, zone_id, typ, year, prefix) FROM stdin;
2	1	1	2013	121300001
4	2	1	2013	231300001
5	1	0	2014	111400001
6	1	1	2014	121400001
7	2	0	2014	241400001
8	2	1	2014	231400001
9	1	0	2007	110700000
10	1	1	2007	120700000
11	2	0	2007	2407000000
12	2	1	2007	2307000000
13	1	0	2008	110800000
14	1	1	2008	120800000
15	2	0	2008	240800000
16	2	1	2008	230800000
17	1	0	2009	110900000
18	1	1	2009	120900000
19	2	0	2009	240900000
20	2	1	2009	230900000
21	1	0	2010	111000000
22	1	1	2010	121000000
23	2	0	2010	241000000
24	2	1	2010	231000000
25	1	0	2011	111100000
26	2	0	2011	241100000
27	1	1	2011	121100000
28	2	1	2011	231100000
1	1	0	2013	111300006
3	2	0	2013	241300008
\.


--
-- Data for Name: invoice_registrar_credit_transaction_map; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY invoice_registrar_credit_transaction_map (id, invoice_id, registrar_credit_transaction_id) FROM stdin;
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
\.


--
-- Data for Name: invoice_type; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY invoice_type (id, name) FROM stdin;
0	advance
1	account
\.


--
-- Data for Name: keyset; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY keyset (id) FROM stdin;
18
19
20
21
22
23
24
25
26
27
\.


--
-- Data for Name: keyset_contact_map; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY keyset_contact_map (keysetid, contactid) FROM stdin;
18	6
18	4
19	6
19	4
20	6
20	4
21	6
21	4
22	6
22	4
23	6
23	4
24	6
24	4
25	6
25	4
26	6
26	4
27	6
27	4
\.


--
-- Data for Name: keyset_contact_map_history; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY keyset_contact_map_history (historyid, keysetid, contactid) FROM stdin;
18	18	6
18	18	4
19	19	6
19	19	4
20	20	6
20	20	4
21	21	6
21	21	4
22	22	6
22	22	4
23	23	6
23	23	4
24	24	6
24	24	4
25	25	6
25	25	4
26	26	6
26	26	4
27	27	6
27	27	4
\.


--
-- Data for Name: keyset_history; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY keyset_history (historyid, id) FROM stdin;
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
\.


--
-- Data for Name: letter_archive; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY letter_archive (id, file_id, batch_id, postal_address_name, postal_address_organization, postal_address_street1, postal_address_street2, postal_address_street3, postal_address_city, postal_address_stateorprovince, postal_address_postalcode, postal_address_country, postal_address_id) FROM stdin;
\.


--
-- Data for Name: mail_archive; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY mail_archive (id, mailtype, crdate, moddate, status, message, attempt, response) FROM stdin;
1	10	2013-06-14 13:31:49.537917	\N	1	Content-Type: multipart/mixed; boundary="===============3176037233257605834=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_kontaktu_CONTACT_/_Contact_CONTACT_registration_notification?=\nTo: freddy+notify@nic.czcz\nMessage-ID: <1.1371216709@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============3176037233257605834==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace kontaktu / Contact create \nIdentifikátor kontaktu / Contact handle : CONTACT\nČíslo žádosti / Ticket :  ReqID-0000000002\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nDetail kontaktu najdete na http://whois.nic.cz?q=CONTACT\nFor detail information about contact visit http://whois.nic.cz?q=CONTACT\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============3176037233257605834==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============3176037233257605834==--	0	\N
2	10	2013-06-14 13:31:49.831744	\N	1	Content-Type: multipart/mixed; boundary="===============3925353708705026464=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_kontaktu_CIHAK_/_Contact_CIHAK_registration_notification?=\nTo: cihak+notify@nic.czcz\nMessage-ID: <2.1371216709@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============3925353708705026464==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace kontaktu / Contact create \nIdentifikátor kontaktu / Contact handle : CIHAK\nČíslo žádosti / Ticket :  ReqID-0000000005\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nDetail kontaktu najdete na http://whois.nic.cz?q=CIHAK\nFor detail information about contact visit http://whois.nic.cz?q=CIHAK\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============3925353708705026464==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============3925353708705026464==--	0	\N
3	10	2013-06-14 13:31:50.126234	\N	1	Content-Type: multipart/mixed; boundary="===============7606264111536725326=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_kontaktu_PEPA_/_Contact_PEPA_registration_notification?=\nTo: pepa+notify@nic.czcz\nMessage-ID: <3.1371216710@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============7606264111536725326==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace kontaktu / Contact create \nIdentifikátor kontaktu / Contact handle : PEPA\nČíslo žádosti / Ticket :  ReqID-0000000008\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nDetail kontaktu najdete na http://whois.nic.cz?q=PEPA\nFor detail information about contact visit http://whois.nic.cz?q=PEPA\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============7606264111536725326==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============7606264111536725326==--	0	\N
4	10	2013-06-14 13:31:50.423645	\N	1	Content-Type: multipart/mixed; boundary="===============7188481561555521505=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_kontaktu_ANNA_/_Contact_ANNA_registration_notification?=\nTo: anna+notify@nic.czcz\nMessage-ID: <4.1371216710@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============7188481561555521505==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace kontaktu / Contact create \nIdentifikátor kontaktu / Contact handle : ANNA\nČíslo žádosti / Ticket :  ReqID-0000000011\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nDetail kontaktu najdete na http://whois.nic.cz?q=ANNA\nFor detail information about contact visit http://whois.nic.cz?q=ANNA\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============7188481561555521505==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============7188481561555521505==--	0	\N
5	10	2013-06-14 13:31:50.725088	\N	1	Content-Type: multipart/mixed; boundary="===============2795000315703531294=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_kontaktu_FRANTA_/_Contact_FRANTA_registration_notification?=\nTo: franta+notify@nic.czcz\nMessage-ID: <5.1371216710@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============2795000315703531294==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace kontaktu / Contact create \nIdentifikátor kontaktu / Contact handle : FRANTA\nČíslo žádosti / Ticket :  ReqID-0000000014\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nDetail kontaktu najdete na http://whois.nic.cz?q=FRANTA\nFor detail information about contact visit http://whois.nic.cz?q=FRANTA\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============2795000315703531294==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============2795000315703531294==--	0	\N
6	10	2013-06-14 13:31:51.018422	\N	1	Content-Type: multipart/mixed; boundary="===============3247955101238942226=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_kontaktu_TESTER_/_Contact_TESTER_registration_notification?=\nTo: tester+notify@nic.czcz\nMessage-ID: <6.1371216711@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============3247955101238942226==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace kontaktu / Contact create \nIdentifikátor kontaktu / Contact handle : TESTER\nČíslo žádosti / Ticket :  ReqID-0000000017\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nDetail kontaktu najdete na http://whois.nic.cz?q=TESTER\nFor detail information about contact visit http://whois.nic.cz?q=TESTER\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============3247955101238942226==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============3247955101238942226==--	0	\N
7	10	2013-06-14 13:31:51.323991	\N	1	Content-Type: multipart/mixed; boundary="===============2621067780859103356=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_kontaktu_BOB_/_Contact_BOB_registration_notification?=\nTo: bob+notify@nic.czcz\nMessage-ID: <7.1371216711@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============2621067780859103356==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace kontaktu / Contact create \nIdentifikátor kontaktu / Contact handle : BOB\nČíslo žádosti / Ticket :  ReqID-0000000020\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nDetail kontaktu najdete na http://whois.nic.cz?q=BOB\nFor detail information about contact visit http://whois.nic.cz?q=BOB\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============2621067780859103356==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============2621067780859103356==--	0	\N
8	10	2013-06-14 13:31:51.749328	\N	1	Content-Type: multipart/mixed; boundary="===============6947236039058709418=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_sady_nameserver=C5=AF_NSSID01_/_NS_set_NSSID01_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <8.1371216711@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============6947236039058709418==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace sady nameserverů / NS set create \nIdentifikátor sady nameserverů / NS set handle : NSSID01\nČíslo žádosti / Ticket :  ReqID-0000000023\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nDetail sady nameserverů najdete na http://whois.nic.cz?q=NSSID01\nFor detail information about nsset visit http://whois.nic.cz?q=NSSID01\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============6947236039058709418==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============6947236039058709418==--	0	\N
9	10	2013-06-14 13:31:52.034049	\N	1	Content-Type: multipart/mixed; boundary="===============3439091644570023131=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_sady_nameserver=C5=AF_NSSID02_/_NS_set_NSSID02_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <9.1371216712@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============3439091644570023131==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace sady nameserverů / NS set create \nIdentifikátor sady nameserverů / NS set handle : NSSID02\nČíslo žádosti / Ticket :  ReqID-0000000026\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nDetail sady nameserverů najdete na http://whois.nic.cz?q=NSSID02\nFor detail information about nsset visit http://whois.nic.cz?q=NSSID02\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============3439091644570023131==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============3439091644570023131==--	0	\N
10	10	2013-06-14 13:31:52.328888	\N	1	Content-Type: multipart/mixed; boundary="===============0299295598032896930=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_sady_nameserver=C5=AF_NSSID03_/_NS_set_NSSID03_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <10.1371216712@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============0299295598032896930==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace sady nameserverů / NS set create \nIdentifikátor sady nameserverů / NS set handle : NSSID03\nČíslo žádosti / Ticket :  ReqID-0000000029\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nDetail sady nameserverů najdete na http://whois.nic.cz?q=NSSID03\nFor detail information about nsset visit http://whois.nic.cz?q=NSSID03\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============0299295598032896930==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============0299295598032896930==--	0	\N
11	10	2013-06-14 13:31:52.60187	\N	1	Content-Type: multipart/mixed; boundary="===============3376825574730034473=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_sady_nameserver=C5=AF_NSSID04_/_NS_set_NSSID04_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <11.1371216712@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============3376825574730034473==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace sady nameserverů / NS set create \nIdentifikátor sady nameserverů / NS set handle : NSSID04\nČíslo žádosti / Ticket :  ReqID-0000000032\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nDetail sady nameserverů najdete na http://whois.nic.cz?q=NSSID04\nFor detail information about nsset visit http://whois.nic.cz?q=NSSID04\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============3376825574730034473==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============3376825574730034473==--	0	\N
12	10	2013-06-14 13:31:52.904304	\N	1	Content-Type: multipart/mixed; boundary="===============5800787345593587929=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_sady_nameserver=C5=AF_NSSID05_/_NS_set_NSSID05_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <12.1371216712@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============5800787345593587929==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace sady nameserverů / NS set create \nIdentifikátor sady nameserverů / NS set handle : NSSID05\nČíslo žádosti / Ticket :  ReqID-0000000035\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nDetail sady nameserverů najdete na http://whois.nic.cz?q=NSSID05\nFor detail information about nsset visit http://whois.nic.cz?q=NSSID05\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============5800787345593587929==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============5800787345593587929==--	0	\N
13	10	2013-06-14 13:31:53.193227	\N	1	Content-Type: multipart/mixed; boundary="===============6226140564808883311=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_sady_nameserver=C5=AF_NSSID06_/_NS_set_NSSID06_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <13.1371216713@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============6226140564808883311==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace sady nameserverů / NS set create \nIdentifikátor sady nameserverů / NS set handle : NSSID06\nČíslo žádosti / Ticket :  ReqID-0000000038\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nDetail sady nameserverů najdete na http://whois.nic.cz?q=NSSID06\nFor detail information about nsset visit http://whois.nic.cz?q=NSSID06\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============6226140564808883311==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============6226140564808883311==--	0	\N
14	10	2013-06-14 13:31:53.488392	\N	1	Content-Type: multipart/mixed; boundary="===============3112487406146655271=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_sady_nameserver=C5=AF_NSSID07_/_NS_set_NSSID07_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <14.1371216713@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============3112487406146655271==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace sady nameserverů / NS set create \nIdentifikátor sady nameserverů / NS set handle : NSSID07\nČíslo žádosti / Ticket :  ReqID-0000000041\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nDetail sady nameserverů najdete na http://whois.nic.cz?q=NSSID07\nFor detail information about nsset visit http://whois.nic.cz?q=NSSID07\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============3112487406146655271==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============3112487406146655271==--	0	\N
15	10	2013-06-14 13:31:53.782799	\N	1	Content-Type: multipart/mixed; boundary="===============3271331173577438712=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_sady_nameserver=C5=AF_NSSID08_/_NS_set_NSSID08_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <15.1371216713@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============3271331173577438712==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace sady nameserverů / NS set create \nIdentifikátor sady nameserverů / NS set handle : NSSID08\nČíslo žádosti / Ticket :  ReqID-0000000044\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nDetail sady nameserverů najdete na http://whois.nic.cz?q=NSSID08\nFor detail information about nsset visit http://whois.nic.cz?q=NSSID08\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============3271331173577438712==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============3271331173577438712==--	0	\N
16	10	2013-06-14 13:31:54.080333	\N	1	Content-Type: multipart/mixed; boundary="===============0627611267320114547=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_sady_nameserver=C5=AF_NSSID09_/_NS_set_NSSID09_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <16.1371216714@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============0627611267320114547==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace sady nameserverů / NS set create \nIdentifikátor sady nameserverů / NS set handle : NSSID09\nČíslo žádosti / Ticket :  ReqID-0000000047\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nDetail sady nameserverů najdete na http://whois.nic.cz?q=NSSID09\nFor detail information about nsset visit http://whois.nic.cz?q=NSSID09\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============0627611267320114547==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============0627611267320114547==--	0	\N
17	10	2013-06-14 13:31:54.368845	\N	1	Content-Type: multipart/mixed; boundary="===============6493710689330730479=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_sady_nameserver=C5=AF_NSSID10_/_NS_set_NSSID10_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <17.1371216714@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============6493710689330730479==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace sady nameserverů / NS set create \nIdentifikátor sady nameserverů / NS set handle : NSSID10\nČíslo žádosti / Ticket :  ReqID-0000000050\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nDetail sady nameserverů najdete na http://whois.nic.cz?q=NSSID10\nFor detail information about nsset visit http://whois.nic.cz?q=NSSID10\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============6493710689330730479==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============6493710689330730479==--	0	\N
18	10	2013-06-14 13:31:54.652589	\N	1	Content-Type: multipart/mixed; boundary="===============2195038606126358538=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_sady_kl=C3=AD=C4=8D=C5=AF_KEYID01_/_Keyset_KEYID01_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <18.1371216714@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============2195038606126358538==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace sady klíčů / Keyset create \nIdentifikátor sady klíčů / Keyset handle : KEYID01\nČíslo žádosti / Ticket :  ReqID-0000000053\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nDetail sady klíčů najdete na http://whois.nic.cz?q=KEYID01\nFor detail information about keyset visit http://whois.nic.cz?q=KEYID01\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============2195038606126358538==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============2195038606126358538==--	0	\N
19	10	2013-06-14 13:31:54.913153	\N	1	Content-Type: multipart/mixed; boundary="===============6194981251187911161=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_sady_kl=C3=AD=C4=8D=C5=AF_KEYID02_/_Keyset_KEYID02_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <19.1371216714@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============6194981251187911161==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace sady klíčů / Keyset create \nIdentifikátor sady klíčů / Keyset handle : KEYID02\nČíslo žádosti / Ticket :  ReqID-0000000056\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nDetail sady klíčů najdete na http://whois.nic.cz?q=KEYID02\nFor detail information about keyset visit http://whois.nic.cz?q=KEYID02\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============6194981251187911161==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============6194981251187911161==--	0	\N
20	10	2013-06-14 13:31:55.194856	\N	1	Content-Type: multipart/mixed; boundary="===============7550544764276846338=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_sady_kl=C3=AD=C4=8D=C5=AF_KEYID03_/_Keyset_KEYID03_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <20.1371216715@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============7550544764276846338==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace sady klíčů / Keyset create \nIdentifikátor sady klíčů / Keyset handle : KEYID03\nČíslo žádosti / Ticket :  ReqID-0000000059\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nDetail sady klíčů najdete na http://whois.nic.cz?q=KEYID03\nFor detail information about keyset visit http://whois.nic.cz?q=KEYID03\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============7550544764276846338==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============7550544764276846338==--	0	\N
21	10	2013-06-14 13:31:55.473307	\N	1	Content-Type: multipart/mixed; boundary="===============8077284457304691359=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_sady_kl=C3=AD=C4=8D=C5=AF_KEYID04_/_Keyset_KEYID04_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <21.1371216715@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============8077284457304691359==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace sady klíčů / Keyset create \nIdentifikátor sady klíčů / Keyset handle : KEYID04\nČíslo žádosti / Ticket :  ReqID-0000000062\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nDetail sady klíčů najdete na http://whois.nic.cz?q=KEYID04\nFor detail information about keyset visit http://whois.nic.cz?q=KEYID04\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============8077284457304691359==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============8077284457304691359==--	0	\N
22	10	2013-06-14 13:31:55.756272	\N	1	Content-Type: multipart/mixed; boundary="===============3674611379975167759=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_sady_kl=C3=AD=C4=8D=C5=AF_KEYID05_/_Keyset_KEYID05_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <22.1371216715@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============3674611379975167759==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace sady klíčů / Keyset create \nIdentifikátor sady klíčů / Keyset handle : KEYID05\nČíslo žádosti / Ticket :  ReqID-0000000065\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nDetail sady klíčů najdete na http://whois.nic.cz?q=KEYID05\nFor detail information about keyset visit http://whois.nic.cz?q=KEYID05\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============3674611379975167759==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============3674611379975167759==--	0	\N
23	10	2013-06-14 13:31:56.036283	\N	1	Content-Type: multipart/mixed; boundary="===============8102069439720683153=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_sady_kl=C3=AD=C4=8D=C5=AF_KEYID06_/_Keyset_KEYID06_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <23.1371216716@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============8102069439720683153==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace sady klíčů / Keyset create \nIdentifikátor sady klíčů / Keyset handle : KEYID06\nČíslo žádosti / Ticket :  ReqID-0000000068\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nDetail sady klíčů najdete na http://whois.nic.cz?q=KEYID06\nFor detail information about keyset visit http://whois.nic.cz?q=KEYID06\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============8102069439720683153==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============8102069439720683153==--	0	\N
24	10	2013-06-14 13:31:56.311961	\N	1	Content-Type: multipart/mixed; boundary="===============0095014680024104143=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_sady_kl=C3=AD=C4=8D=C5=AF_KEYID07_/_Keyset_KEYID07_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <24.1371216716@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============0095014680024104143==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace sady klíčů / Keyset create \nIdentifikátor sady klíčů / Keyset handle : KEYID07\nČíslo žádosti / Ticket :  ReqID-0000000071\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nDetail sady klíčů najdete na http://whois.nic.cz?q=KEYID07\nFor detail information about keyset visit http://whois.nic.cz?q=KEYID07\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============0095014680024104143==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============0095014680024104143==--	0	\N
25	10	2013-06-14 13:31:56.593208	\N	1	Content-Type: multipart/mixed; boundary="===============2996475020500501041=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_sady_kl=C3=AD=C4=8D=C5=AF_KEYID08_/_Keyset_KEYID08_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <25.1371216716@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============2996475020500501041==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace sady klíčů / Keyset create \nIdentifikátor sady klíčů / Keyset handle : KEYID08\nČíslo žádosti / Ticket :  ReqID-0000000074\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nDetail sady klíčů najdete na http://whois.nic.cz?q=KEYID08\nFor detail information about keyset visit http://whois.nic.cz?q=KEYID08\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============2996475020500501041==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============2996475020500501041==--	0	\N
26	10	2013-06-14 13:31:56.875519	\N	1	Content-Type: multipart/mixed; boundary="===============7104005876266843723=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_sady_kl=C3=AD=C4=8D=C5=AF_KEYID09_/_Keyset_KEYID09_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <26.1371216716@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============7104005876266843723==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace sady klíčů / Keyset create \nIdentifikátor sady klíčů / Keyset handle : KEYID09\nČíslo žádosti / Ticket :  ReqID-0000000077\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nDetail sady klíčů najdete na http://whois.nic.cz?q=KEYID09\nFor detail information about keyset visit http://whois.nic.cz?q=KEYID09\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============7104005876266843723==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============7104005876266843723==--	0	\N
27	10	2013-06-14 13:31:57.159329	\N	1	Content-Type: multipart/mixed; boundary="===============3411787002500359265=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_sady_kl=C3=AD=C4=8D=C5=AF_KEYID10_/_Keyset_KEYID10_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <27.1371216717@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============3411787002500359265==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace sady klíčů / Keyset create \nIdentifikátor sady klíčů / Keyset handle : KEYID10\nČíslo žádosti / Ticket :  ReqID-0000000080\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nDetail sady klíčů najdete na http://whois.nic.cz?q=KEYID10\nFor detail information about keyset visit http://whois.nic.cz?q=KEYID10\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============3411787002500359265==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============3411787002500359265==--	0	\N
28	10	2013-06-14 13:31:57.461048	\N	1	Content-Type: multipart/mixed; boundary="===============5586242141285532142=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_nic01=2Ecz_/_Domain_nic01=2Ecz_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <28.1371216717@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============5586242141285532142==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : nic01.cz\nČíslo žádosti / Ticket :  ReqID-0000000083\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=nic01.cz\nFor detail information about domain visit http://whois.nic.cz?q=nic01.cz\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============5586242141285532142==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============5586242141285532142==--	0	\N
29	10	2013-06-14 13:31:57.763614	\N	1	Content-Type: multipart/mixed; boundary="===============5478171314410005706=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_nic02=2Ecz_/_Domain_nic02=2Ecz_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <29.1371216717@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============5478171314410005706==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : nic02.cz\nČíslo žádosti / Ticket :  ReqID-0000000086\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=nic02.cz\nFor detail information about domain visit http://whois.nic.cz?q=nic02.cz\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============5478171314410005706==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============5478171314410005706==--	0	\N
30	10	2013-06-14 13:31:58.07898	\N	1	Content-Type: multipart/mixed; boundary="===============2354534528841275778=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_nic03=2Ecz_/_Domain_nic03=2Ecz_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <30.1371216718@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============2354534528841275778==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : nic03.cz\nČíslo žádosti / Ticket :  ReqID-0000000089\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=nic03.cz\nFor detail information about domain visit http://whois.nic.cz?q=nic03.cz\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============2354534528841275778==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============2354534528841275778==--	0	\N
31	10	2013-06-14 13:31:58.397943	\N	1	Content-Type: multipart/mixed; boundary="===============7470467971622741754=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_nic04=2Ecz_/_Domain_nic04=2Ecz_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <31.1371216718@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============7470467971622741754==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : nic04.cz\nČíslo žádosti / Ticket :  ReqID-0000000092\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=nic04.cz\nFor detail information about domain visit http://whois.nic.cz?q=nic04.cz\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============7470467971622741754==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============7470467971622741754==--	0	\N
32	10	2013-06-14 13:31:58.710992	\N	1	Content-Type: multipart/mixed; boundary="===============5994033770760189692=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_nic05=2Ecz_/_Domain_nic05=2Ecz_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <32.1371216718@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============5994033770760189692==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : nic05.cz\nČíslo žádosti / Ticket :  ReqID-0000000095\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=nic05.cz\nFor detail information about domain visit http://whois.nic.cz?q=nic05.cz\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============5994033770760189692==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============5994033770760189692==--	0	\N
33	10	2013-06-14 13:31:59.017752	\N	1	Content-Type: multipart/mixed; boundary="===============4595128522114368231=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_nic06=2Ecz_/_Domain_nic06=2Ecz_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <33.1371216719@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============4595128522114368231==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : nic06.cz\nČíslo žádosti / Ticket :  ReqID-0000000098\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=nic06.cz\nFor detail information about domain visit http://whois.nic.cz?q=nic06.cz\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============4595128522114368231==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============4595128522114368231==--	0	\N
34	10	2013-06-14 13:31:59.327223	\N	1	Content-Type: multipart/mixed; boundary="===============8821289007908857651=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_nic07=2Ecz_/_Domain_nic07=2Ecz_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <34.1371216719@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============8821289007908857651==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : nic07.cz\nČíslo žádosti / Ticket :  ReqID-0000000101\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=nic07.cz\nFor detail information about domain visit http://whois.nic.cz?q=nic07.cz\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============8821289007908857651==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============8821289007908857651==--	0	\N
35	10	2013-06-14 13:31:59.640835	\N	1	Content-Type: multipart/mixed; boundary="===============2308603201587334486=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_nic08=2Ecz_/_Domain_nic08=2Ecz_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <35.1371216719@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============2308603201587334486==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : nic08.cz\nČíslo žádosti / Ticket :  ReqID-0000000104\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=nic08.cz\nFor detail information about domain visit http://whois.nic.cz?q=nic08.cz\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============2308603201587334486==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============2308603201587334486==--	0	\N
36	10	2013-06-14 13:31:59.947992	\N	1	Content-Type: multipart/mixed; boundary="===============7529885770142669900=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_nic09=2Ecz_/_Domain_nic09=2Ecz_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <36.1371216719@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============7529885770142669900==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : nic09.cz\nČíslo žádosti / Ticket :  ReqID-0000000107\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=nic09.cz\nFor detail information about domain visit http://whois.nic.cz?q=nic09.cz\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============7529885770142669900==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============7529885770142669900==--	0	\N
37	10	2013-06-14 13:32:00.252865	\N	1	Content-Type: multipart/mixed; boundary="===============7160027918697615335=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_nic10=2Ecz_/_Domain_nic10=2Ecz_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <37.1371216720@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============7160027918697615335==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : nic10.cz\nČíslo žádosti / Ticket :  ReqID-0000000110\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=nic10.cz\nFor detail information about domain visit http://whois.nic.cz?q=nic10.cz\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============7160027918697615335==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============7160027918697615335==--	0	\N
38	10	2013-06-14 13:32:00.554611	\N	1	Content-Type: multipart/mixed; boundary="===============6206919854196422857=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_ginger01=2Ecz_/_Domain_ginger01=2Ecz_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <38.1371216720@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============6206919854196422857==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : ginger01.cz\nČíslo žádosti / Ticket :  ReqID-0000000113\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=ginger01.cz\nFor detail information about domain visit http://whois.nic.cz?q=ginger01.cz\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============6206919854196422857==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============6206919854196422857==--	0	\N
39	10	2013-06-14 13:32:00.854718	\N	1	Content-Type: multipart/mixed; boundary="===============7056363254610554126=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_ginger02=2Ecz_/_Domain_ginger02=2Ecz_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <39.1371216720@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============7056363254610554126==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : ginger02.cz\nČíslo žádosti / Ticket :  ReqID-0000000116\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=ginger02.cz\nFor detail information about domain visit http://whois.nic.cz?q=ginger02.cz\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============7056363254610554126==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============7056363254610554126==--	0	\N
40	10	2013-06-14 13:32:01.159888	\N	1	Content-Type: multipart/mixed; boundary="===============0283599875011729926=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_ginger03=2Ecz_/_Domain_ginger03=2Ecz_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <40.1371216721@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============0283599875011729926==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : ginger03.cz\nČíslo žádosti / Ticket :  ReqID-0000000119\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=ginger03.cz\nFor detail information about domain visit http://whois.nic.cz?q=ginger03.cz\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============0283599875011729926==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============0283599875011729926==--	0	\N
41	10	2013-06-14 13:32:01.472527	\N	1	Content-Type: multipart/mixed; boundary="===============3882354347939304501=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_ginger04=2Ecz_/_Domain_ginger04=2Ecz_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <41.1371216721@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============3882354347939304501==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : ginger04.cz\nČíslo žádosti / Ticket :  ReqID-0000000122\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=ginger04.cz\nFor detail information about domain visit http://whois.nic.cz?q=ginger04.cz\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============3882354347939304501==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============3882354347939304501==--	0	\N
42	10	2013-06-14 13:32:01.78206	\N	1	Content-Type: multipart/mixed; boundary="===============3961189565760197275=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_ginger05=2Ecz_/_Domain_ginger05=2Ecz_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <42.1371216721@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============3961189565760197275==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : ginger05.cz\nČíslo žádosti / Ticket :  ReqID-0000000125\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=ginger05.cz\nFor detail information about domain visit http://whois.nic.cz?q=ginger05.cz\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============3961189565760197275==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============3961189565760197275==--	0	\N
43	10	2013-06-14 13:32:02.10242	\N	1	Content-Type: multipart/mixed; boundary="===============2031667473758585647=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_ginger06=2Ecz_/_Domain_ginger06=2Ecz_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <43.1371216722@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============2031667473758585647==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : ginger06.cz\nČíslo žádosti / Ticket :  ReqID-0000000128\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=ginger06.cz\nFor detail information about domain visit http://whois.nic.cz?q=ginger06.cz\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============2031667473758585647==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============2031667473758585647==--	0	\N
44	10	2013-06-14 13:32:02.406071	\N	1	Content-Type: multipart/mixed; boundary="===============4760089389090352603=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_ginger07=2Ecz_/_Domain_ginger07=2Ecz_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <44.1371216722@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============4760089389090352603==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : ginger07.cz\nČíslo žádosti / Ticket :  ReqID-0000000131\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=ginger07.cz\nFor detail information about domain visit http://whois.nic.cz?q=ginger07.cz\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============4760089389090352603==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============4760089389090352603==--	0	\N
45	10	2013-06-14 13:32:02.710479	\N	1	Content-Type: multipart/mixed; boundary="===============3540022481011774354=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_ginger08=2Ecz_/_Domain_ginger08=2Ecz_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <45.1371216722@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============3540022481011774354==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : ginger08.cz\nČíslo žádosti / Ticket :  ReqID-0000000134\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=ginger08.cz\nFor detail information about domain visit http://whois.nic.cz?q=ginger08.cz\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============3540022481011774354==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============3540022481011774354==--	0	\N
46	10	2013-06-14 13:32:03.012709	\N	1	Content-Type: multipart/mixed; boundary="===============8607016728399777538=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_ginger09=2Ecz_/_Domain_ginger09=2Ecz_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <46.1371216723@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============8607016728399777538==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : ginger09.cz\nČíslo žádosti / Ticket :  ReqID-0000000137\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=ginger09.cz\nFor detail information about domain visit http://whois.nic.cz?q=ginger09.cz\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============8607016728399777538==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============8607016728399777538==--	0	\N
47	10	2013-06-14 13:32:03.308006	\N	1	Content-Type: multipart/mixed; boundary="===============7983820254375972266=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_ginger10=2Ecz_/_Domain_ginger10=2Ecz_registration_notification?=\nTo: anna+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <47.1371216723@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============7983820254375972266==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : ginger10.cz\nČíslo žádosti / Ticket :  ReqID-0000000140\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=ginger10.cz\nFor detail information about domain visit http://whois.nic.cz?q=ginger10.cz\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============7983820254375972266==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============7983820254375972266==--	0	\N
48	10	2013-06-14 13:32:03.622855	\N	1	Content-Type: multipart/mixed; boundary="===============1169355905847962736=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_1=2E1=2E1=2E8=2E4=2E5=2E2=2E2=2E2=2E0=2E2=2E4=2Ee164=2Earpa_/_Domain_1=2E1=2E1=2E8=2E4=2E5=2E2=2E2=2E2=2E0=2E2=2E4=2Ee164=2Earpa_registration_notification?=\nTo: anna+notify@nic.czcz, bob+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <48.1371216723@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============1169355905847962736==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : 1.1.1.8.4.5.2.2.2.0.2.4.e164.arpa\nČíslo žádosti / Ticket :  ReqID-0000000143\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=1.1.1.8.4.5.2.2.2.0.2.4.e164.arpa\nFor detail information about domain visit http://whois.nic.cz?q=1.1.1.8.4.5.2.2.2.0.2.4.e164.arpa\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============1169355905847962736==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============1169355905847962736==--	0	\N
49	10	2013-06-14 13:32:03.936948	\N	1	Content-Type: multipart/mixed; boundary="===============4028613789276579815=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_2=2E1=2E1=2E8=2E4=2E5=2E2=2E2=2E2=2E0=2E2=2E4=2Ee164=2Earpa_/_Domain_2=2E1=2E1=2E8=2E4=2E5=2E2=2E2=2E2=2E0=2E2=2E4=2Ee164=2Earpa_registration_notification?=\nTo: anna+notify@nic.czcz, bob+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <49.1371216723@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============4028613789276579815==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : 2.1.1.8.4.5.2.2.2.0.2.4.e164.arpa\nČíslo žádosti / Ticket :  ReqID-0000000146\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=2.1.1.8.4.5.2.2.2.0.2.4.e164.arpa\nFor detail information about domain visit http://whois.nic.cz?q=2.1.1.8.4.5.2.2.2.0.2.4.e164.arpa\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============4028613789276579815==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============4028613789276579815==--	0	\N
50	10	2013-06-14 13:32:04.257147	\N	1	Content-Type: multipart/mixed; boundary="===============4456281529507083347=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_3=2E1=2E1=2E8=2E4=2E5=2E2=2E2=2E2=2E0=2E2=2E4=2Ee164=2Earpa_/_Domain_3=2E1=2E1=2E8=2E4=2E5=2E2=2E2=2E2=2E0=2E2=2E4=2Ee164=2Earpa_registration_notification?=\nTo: anna+notify@nic.czcz, bob+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <50.1371216724@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============4456281529507083347==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : 3.1.1.8.4.5.2.2.2.0.2.4.e164.arpa\nČíslo žádosti / Ticket :  ReqID-0000000149\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=3.1.1.8.4.5.2.2.2.0.2.4.e164.arpa\nFor detail information about domain visit http://whois.nic.cz?q=3.1.1.8.4.5.2.2.2.0.2.4.e164.arpa\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============4456281529507083347==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============4456281529507083347==--	0	\N
51	10	2013-06-14 13:32:04.574459	\N	1	Content-Type: multipart/mixed; boundary="===============4704823106692083436=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_4=2E1=2E1=2E8=2E4=2E5=2E2=2E2=2E2=2E0=2E2=2E4=2Ee164=2Earpa_/_Domain_4=2E1=2E1=2E8=2E4=2E5=2E2=2E2=2E2=2E0=2E2=2E4=2Ee164=2Earpa_registration_notification?=\nTo: anna+notify@nic.czcz, bob+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <51.1371216724@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============4704823106692083436==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : 4.1.1.8.4.5.2.2.2.0.2.4.e164.arpa\nČíslo žádosti / Ticket :  ReqID-0000000152\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=4.1.1.8.4.5.2.2.2.0.2.4.e164.arpa\nFor detail information about domain visit http://whois.nic.cz?q=4.1.1.8.4.5.2.2.2.0.2.4.e164.arpa\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============4704823106692083436==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============4704823106692083436==--	0	\N
52	10	2013-06-14 13:32:04.890793	\N	1	Content-Type: multipart/mixed; boundary="===============4306346514900090226=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_5=2E1=2E1=2E8=2E4=2E5=2E2=2E2=2E2=2E0=2E2=2E4=2Ee164=2Earpa_/_Domain_5=2E1=2E1=2E8=2E4=2E5=2E2=2E2=2E2=2E0=2E2=2E4=2Ee164=2Earpa_registration_notification?=\nTo: anna+notify@nic.czcz, bob+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <52.1371216724@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============4306346514900090226==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : 5.1.1.8.4.5.2.2.2.0.2.4.e164.arpa\nČíslo žádosti / Ticket :  ReqID-0000000155\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=5.1.1.8.4.5.2.2.2.0.2.4.e164.arpa\nFor detail information about domain visit http://whois.nic.cz?q=5.1.1.8.4.5.2.2.2.0.2.4.e164.arpa\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============4306346514900090226==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============4306346514900090226==--	0	\N
53	10	2013-06-14 13:32:05.208436	\N	1	Content-Type: multipart/mixed; boundary="===============7211188476745738972=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_6=2E1=2E1=2E8=2E4=2E5=2E2=2E2=2E2=2E0=2E2=2E4=2Ee164=2Earpa_/_Domain_6=2E1=2E1=2E8=2E4=2E5=2E2=2E2=2E2=2E0=2E2=2E4=2Ee164=2Earpa_registration_notification?=\nTo: anna+notify@nic.czcz, bob+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <53.1371216725@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============7211188476745738972==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : 6.1.1.8.4.5.2.2.2.0.2.4.e164.arpa\nČíslo žádosti / Ticket :  ReqID-0000000158\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=6.1.1.8.4.5.2.2.2.0.2.4.e164.arpa\nFor detail information about domain visit http://whois.nic.cz?q=6.1.1.8.4.5.2.2.2.0.2.4.e164.arpa\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============7211188476745738972==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============7211188476745738972==--	0	\N
54	10	2013-06-14 13:32:05.529935	\N	1	Content-Type: multipart/mixed; boundary="===============0555167266332940939=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_7=2E1=2E1=2E8=2E4=2E5=2E2=2E2=2E2=2E0=2E2=2E4=2Ee164=2Earpa_/_Domain_7=2E1=2E1=2E8=2E4=2E5=2E2=2E2=2E2=2E0=2E2=2E4=2Ee164=2Earpa_registration_notification?=\nTo: anna+notify@nic.czcz, bob+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <54.1371216725@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============0555167266332940939==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : 7.1.1.8.4.5.2.2.2.0.2.4.e164.arpa\nČíslo žádosti / Ticket :  ReqID-0000000161\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=7.1.1.8.4.5.2.2.2.0.2.4.e164.arpa\nFor detail information about domain visit http://whois.nic.cz?q=7.1.1.8.4.5.2.2.2.0.2.4.e164.arpa\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============0555167266332940939==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============0555167266332940939==--	0	\N
55	10	2013-06-14 13:32:05.839271	\N	1	Content-Type: multipart/mixed; boundary="===============4341464129804894294=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_8=2E1=2E1=2E8=2E4=2E5=2E2=2E2=2E2=2E0=2E2=2E4=2Ee164=2Earpa_/_Domain_8=2E1=2E1=2E8=2E4=2E5=2E2=2E2=2E2=2E0=2E2=2E4=2Ee164=2Earpa_registration_notification?=\nTo: anna+notify@nic.czcz, bob+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <55.1371216725@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============4341464129804894294==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : 8.1.1.8.4.5.2.2.2.0.2.4.e164.arpa\nČíslo žádosti / Ticket :  ReqID-0000000164\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=8.1.1.8.4.5.2.2.2.0.2.4.e164.arpa\nFor detail information about domain visit http://whois.nic.cz?q=8.1.1.8.4.5.2.2.2.0.2.4.e164.arpa\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============4341464129804894294==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============4341464129804894294==--	0	\N
56	10	2013-06-14 13:32:06.14951	\N	1	Content-Type: multipart/mixed; boundary="===============2183719069632221628=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_9=2E1=2E1=2E8=2E4=2E5=2E2=2E2=2E2=2E0=2E2=2E4=2Ee164=2Earpa_/_Domain_9=2E1=2E1=2E8=2E4=2E5=2E2=2E2=2E2=2E0=2E2=2E4=2Ee164=2Earpa_registration_notification?=\nTo: anna+notify@nic.czcz, bob+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <56.1371216726@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============2183719069632221628==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : 9.1.1.8.4.5.2.2.2.0.2.4.e164.arpa\nČíslo žádosti / Ticket :  ReqID-0000000167\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=9.1.1.8.4.5.2.2.2.0.2.4.e164.arpa\nFor detail information about domain visit http://whois.nic.cz?q=9.1.1.8.4.5.2.2.2.0.2.4.e164.arpa\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============2183719069632221628==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============2183719069632221628==--	0	\N
57	10	2013-06-14 13:32:06.456809	\N	1	Content-Type: multipart/mixed; boundary="===============2609034381439043584=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_0=2E2=2E1=2E8=2E4=2E5=2E2=2E2=2E2=2E0=2E2=2E4=2Ee164=2Earpa_/_Domain_0=2E2=2E1=2E8=2E4=2E5=2E2=2E2=2E2=2E0=2E2=2E4=2Ee164=2Earpa_registration_notification?=\nTo: anna+notify@nic.czcz, bob+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <57.1371216726@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============2609034381439043584==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : 0.2.1.8.4.5.2.2.2.0.2.4.e164.arpa\nČíslo žádosti / Ticket :  ReqID-0000000170\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=0.2.1.8.4.5.2.2.2.0.2.4.e164.arpa\nFor detail information about domain visit http://whois.nic.cz?q=0.2.1.8.4.5.2.2.2.0.2.4.e164.arpa\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============2609034381439043584==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============2609034381439043584==--	0	\N
58	10	2013-06-14 13:32:06.768158	\N	1	Content-Type: multipart/mixed; boundary="===============3499434932247020600=="\nMIME-Version: 1.0\nSubject: =?utf-8?q?Ozn=C3=A1men=C3=AD_o_registraci_dom=C3=A9ny_1=2E2=2E1=2E8=2E4=2E5=2E2=2E2=2E2=2E0=2E2=2E4=2Ee164=2Earpa_/_Domain_1=2E2=2E1=2E8=2E4=2E5=2E2=2E2=2E2=2E0=2E2=2E4=2Ee164=2Earpa_registration_notification?=\nTo: anna+notify@nic.czcz, bob+notify@nic.czcz, tester+notify@nic.czcz\nMessage-ID: <58.1371216726@nic.cz>\nFrom: podpora@nic.cz\nReply-to: podpora@nic.cz\nErrors-to: podpora@nic.cz\nOrganization: =?utf-8?q?CZ=2ENIC=2C_z=2Es=2Ep=2Eo=2E?=\n\n--===============3499434932247020600==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/plain; charset="utf-8"\n\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace domény / Domain create \nIdentifikátor domény / Domain handle : 1.2.1.8.4.5.2.2.2.0.2.4.e164.arpa\nČíslo žádosti / Ticket :  ReqID-0000000173\nRegistrátor / Registrar : Company A l.t.d (www.nic.cz)\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na http://whois.nic.cz?q=1.2.1.8.4.5.2.2.2.0.2.4.e164.arpa\nFor detail information about domain visit http://whois.nic.cz?q=1.2.1.8.4.5.2.2.2.0.2.4.e164.arpa\n\n\n                                             S pozdravem\n                                             podpora CZ.NIC, z.s.p.o\n\n-- \nCZ.NIC, z.s.p.o\nAmericka 23\n120 00 Praha 2\n---------------------------------\ntel.: +420 222 745 111\nfax : +420 222 745 112\ne-mail : podpora@nic.cz\n---------------------------------\n\n--===============3499434932247020600==\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\nContent-Type: text/x-vcard; charset="utf-8"\n\nBEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n\n--===============3499434932247020600==--	0	\N
\.


--
-- Data for Name: mail_attachments; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY mail_attachments (id, mailid, attachid) FROM stdin;
\.


--
-- Data for Name: mail_defaults; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY mail_defaults (id, name, value) FROM stdin;
1	company	CZ.NIC, z.s.p.o
2	street	Americka 23
3	postalcode	120 00
4	city	Praha 2
5	tel	+420 222 745 111
6	fax	+420 222 745 112
7	emailsupport	podpora@nic.cz
8	authinfopage	http://www.nic.cz/whois/publicrequest/
9	whoispage	http://whois.nic.cz
\.


--
-- Data for Name: mail_footer; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY mail_footer (id, footer) FROM stdin;
1	-- \n<?cs var:defaults.company ?>\n<?cs var:defaults.street ?>\n<?cs var:defaults.postalcode ?> <?cs var:defaults.city ?>\n---------------------------------\ntel.: <?cs var:defaults.tel ?>\nfax : <?cs var:defaults.fax ?>\ne-mail : <?cs var:defaults.emailsupport ?>\n---------------------------------\n
\.


--
-- Data for Name: mail_handles; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY mail_handles (id, mailid, associd) FROM stdin;
\.


--
-- Data for Name: mail_header_defaults; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY mail_header_defaults (id, h_from, h_replyto, h_errorsto, h_organization, h_contentencoding, h_messageidserver) FROM stdin;
1	podpora@nic.cz	podpora@nic.cz	podpora@nic.cz	CZ.NIC, z.s.p.o.	charset=UTF-8	nic.cz
\.


--
-- Data for Name: mail_templates; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY mail_templates (id, contenttype, template, footer) FROM stdin;
1	plain	English version of the e-mail is entered below the Czech version\n\nZaslání autorizační informace\n\nVážený zákazníku,\n\n   na základě Vaší žádosti podané prostřednictvím webového formuláře\nna stránkách sdružení dne <?cs var:reqdate ?>, které\nbylo přiděleno identifikační číslo <?cs var:reqid ?>, Vám zasíláme požadované\nheslo, příslušející <?cs if:type == #3 ?>k doméně<?cs elif:type == #1 ?>ke kontaktu s identifikátorem<?cs elif:type == #2 ?>k sadě nameserverů s identifikátorem<?cs elif:type == #4 ?>k sadě klíčů s identifikátorem<?cs /if ?> <?cs var:handle ?>.\n\n   Heslo je: <?cs var:authinfo ?>\n\n   V případě, že jste tuto žádost nepodali, oznamte prosím tuto\nskutečnost na adresu <?cs var:defaults.emailsupport ?>.\n\n                                             S pozdravem\n                                             podpora <?cs var:defaults.company ?>\n\n\n\nSending authorization information\n\nDear customer,\n\n   Based on your request submitted via the web form on the association\npages on <?cs var:reqdate ?>, which received\nthe identification number <?cs var:reqid ?>, we are sending you the requested\npassword that belongs to the <?cs if:type == #3 ?>domain name<?cs elif:type == #1 ?>contact with identifier<?cs elif:type == #2 ?>NS set with identifier<?cs elif:type == #4 ?>Keyset with identifier<?cs /if ?> <?cs var:handle ?>.\n\n   The password is: <?cs var:authinfo ?>\n\n   If you did not submit the aforementioned request, please notify us about\nthis fact at the following address <?cs var:defaults.emailsupport ?>.\n\n\n                                             Yours sincerely\n                                             support <?cs var:defaults.company ?>\n	1
2	plain	 English version of the e-mail is entered below the Czech version\n\nZaslání autorizační informace\n\nVážený zákazníku,\n\n   na základě Vaší žádosti, podané prostřednictvím registrátora\n<?cs var:registrar ?>, Vám zasíláme požadované heslo\npříslušející <?cs if:type == #3 ?>k doméně<?cs elif:type == #1 ?>ke kontaktu s identifikátorem<?cs elif:type == #2 ?>k sadě nameserverů s identifikátorem<?cs elif:type == #4 ?>k sadě klíčů s identifikátorem<?cs /if ?> <?cs var:handle ?>.\n\n   Heslo je: <?cs var:authinfo ?>\n\n   Tato zpráva je zaslána pouze na e-mailovou adresu uvedenou u příslušné\nosoby v Centrálním registru doménových jmen.\n\n   V případě, že jste tuto žádost nepodali, oznamte prosím tuto\nskutečnost na adresu <?cs var:defaults.emailsupport ?>.\n\n\n                                             S pozdravem\n                                             podpora <?cs var:defaults.company ?>\n\n\n\nSending authorization information\n\nDear customer,\n\n   Based on your request submitted via the registrar <?cs var:registrar ?>,\nwe are sending the requested password that belongs to\nthe <?cs if:type == #3 ?>domain name<?cs elif:type == #1 ?>contact with identifier<?cs elif:type == #2 ?>NS set with identifier<?cs elif:type == #4 ?>Keyset with identifier<?cs /if ?> <?cs var:handle ?>.\n\n   The password is: <?cs var:authinfo ?>\n\n   This message is being sent only to the e-mail address that we have on file\nfor a particular person in the Central Registry of Domain Names.\n\n   If you did not submit the aforementioned request, please notify us about\nthis fact at the following address <?cs var:defaults.emailsupport ?>.\n\n\n                                             Yours sincerely\n                                             support <?cs var:defaults.company ?>\n	1
3	plain	English version of the e-mail is entered below the Czech version\n\nUpozornění na nutnost úhrady domény <?cs var:domain ?>\n\nVážený zákazníku,\n\ndovolujeme si Vás upozornit, že k <?cs var:checkdate ?> dosud nedošlo k prodloužení\nregistrace doménového jména <?cs var:domain ?>. Vzhledem k tomu, že doménové\njméno bylo za uplynulé období zaplaceno pouze do <?cs var:exdate ?>, nachází se\nnyní v takzvané ochranné lhůtě. V případě, že doménové jméno nebude včas\nuhrazeno, budou v souladu s Pravidly registrace doménových jmen nasledovat\ntyto kroky:\n\n<?cs var:dnsdate ?> - Znefunkčnění doménového jména (vyřazení z DNS).\n<?cs var:exregdate ?> - Definitivní zrušení registrace doménového jména.\n\nV této chvíli evidujeme následující údaje o doméně:\n\nDoménové jméno: <?cs var:domain ?>\nDržitel: <?cs var:owner ?>\nRegistrátor: <?cs var:registrar ?>\n<?cs each:item = administrators ?>Administrativní kontakt: <?cs var:item ?>\n<?cs /each ?>\nVzhledem k této situaci máte nyní následující možnosti:\n\n1. Kontaktujte prosím svého registrátora a ve spolupráci s ním zajistěte\n   prodloužení registrace vašeho doménového jména\n\n2. Nebo si vyberte jiného určeného registrátora a jeho prostřednictvím\n   zajistěte prodloužení registrace vašeho doménového jména. Seznam\n   registrátorů najdete na stránkách sdružení (Seznam registrátorů)\n\n\n                                             S pozdravem\n                                             podpora <?cs var:defaults.company ?>\n\n\n\nReminder of the need to settle fees for the <?cs var:domain ?> domain name\n\nDear customer,\n\nWe would like to inform you that as of <?cs var:checkdate ?>, the registration\nof the domain name <?cs var:domain ?> has not been extended. Concerning\nthe fact that the fee for the domain name in question has been paid only\nfor a period ended on <?cs var:exdate ?>, your domain name has now entered\nthe so-called protective period. Unless a registrar of your choice extends\nyour registration, the following steps will be adopted in accordance with\nthe Domain Name Registration Rules:\n\n<?cs var:dnsdate ?> - The domain name will not be accessible (exclusion from DNS).\n<?cs var:exregdate ?> - Final cancellation of the domain name registration.\n\nAt present, our database includes the following details concerning your domain:\n\nDomain name: <?cs var:domain ?>\nHolder: <?cs var:owner ?>\nRegistrar: <?cs var:registrar ?>\n<?cs each:item = administrators ?>Admin contact: <?cs var:item ?>\n<?cs /each ?>\nTo ensure adequate remedy of the existing situation, you can choose\none of the following:\n\n1. Please contact your registrar and make sure that the registration\n   of your domain name is duly extended.\n\n2. Or choose another registrar in order to extend the registration of your\n   domain name. For a list of registrars, please visit association pages\n   (List of Registrars)\n\n\n                                             Yours sincerely\n                                             support <?cs var:defaults.company ?>\n	1
4	plain	English version of the e-mail is entered below the Czech version\n\nOznámení o vyřazení domény <?cs var:domain?> z DNS\n\nVážený zákazníku,\n\ndovolujeme si Vás tímto upozornit, že doposud nebyla uhrazena platba\nza prodloužení doménového jména <?cs var:domain ?>. Vzhledem k této\nskutečnosti a na základě Pravidel registrace doménových jmen,\n<?cs var:defaults.company ?> pozastavuje registraci doménového jména a vyřazuje\nji ze zóny <?cs var:zone ?>.\n\nV případě, že do dne <?cs var:exregdate ?> neobdrží <?cs var:defaults.company ?> od vašeho\nregistrátora platbu za prodloužení platnosti doménového jména, bude\ndoménové jméno definitivně uvolněno pro použití dalším zájemcem, a to\nke dni <?cs var:exregdate ?>.\n\nProsíme kontaktujte Vašeho Určeného registrátora <?cs var:registrar ?>\nza účelem prodloužení doménového jména.\n\nV případě, že se domníváte, že platba byla provedena, prověřte nejdříve,\nzda byla provedena pod spravným variabilním symbolem, na správné číslo\núčtu a ve spravné výši a tyto informace svému Určenému registrátorovi\nsdělte.\n\nHarmonogram plánovaných akcí:\n\n<?cs var:exregdate ?> - Definitivní zrušení registrace doménového jména.\n\nV této chvíli evidujeme následující údaje o doméně:\n\nDoménové jméno: <?cs var:domain ?>\nDržitel: <?cs var:owner ?>\nRegistrátor: <?cs var:registrar ?>\n<?cs each:item = administrators ?>Administrativní kontakt: <?cs var:item ?>\n<?cs /each ?>\n\n                                             S pozdravem\n                                             podpora <?cs var:defaults.company ?>\n\n\n\nNotification about inactivation of the <?cs var:domain?> domain from DNS\n\nDear customer,\n\nWe would like to notify you that the payment for extension of the domain name\n<?cs var:domain ?> has not been received yet. With regard to that fact\nand in accordance with Rules for domain names registrations, <?cs var:defaults.company ?>\nis suspending the domain name registration and is withdrawing it from the\n<?cs var:zone ?> zone.\n\nIn case that by <?cs var:exregdate ?>, <?cs var:defaults.company ?> will not receive the payment\nfor extension of the domain name from your registrar, your domain name will\nbe definitely released for a use by another applicant on <?cs var:exregdate ?>.\n\nPlease, contact your designated registrar <?cs var:registrar ?>\nfor a purpose of extension of the domain name.\n\nIf you believe that the payment was made, please, check first if the payment\nwas made with the correct variable symbol, to the correct account number, and\nwith the correct amount, and convey this information to your designated\nregistrar.\n\nTime-schedule of planned events:\n\n<?cs var:exregdate ?> - Definitive cancellation of the domain name registration.\n\nAt this moment, we have the following information about the domain in our\nrecords:\n\nDomain name: <?cs var:domain ?>\nOwner: <?cs var:owner ?>\nRegistrar: <?cs var:registrar ?>\n<?cs each:item = administrators ?>Admin contact: <?cs var:item ?>\n<?cs /each ?>\n\n                                             Yours sincerely\n                                             support <?cs var:defaults.company ?>\n	1
5	plain	English version of the e-mail is entered below the Czech version\n\nOznámení o zrušení domény <?cs var:domain ?>\n\nVážený zákazníku,\n\ndovolujeme si Vás upozornit, že nebylo provedeno prodloužení registrace\npro doménové jméno <?cs var:domain ?>. Vzhledem k této skutečnosti\na na základě Pravidel registrace doménových jmen, <?cs var:defaults.company ?>\nruší registraci doménového jména.\n\n\n                                             S pozdravem\n                                             podpora <?cs var:defaults.company ?>\n\n\n\nNotification about cancellation of the domain <?cs var:domain ?>\n\nDear customer,\n\nwe would like to inform you that the registration extension has not yet been\nimplemented for the domain name <?cs var:domain ?>. Due to this fact and\nbased on the Domain Name Registration Rules (Pravidla registrace domenovych\njmen), <?cs var:defaults.company ?> is cancelling the domain name registration.\n\n\n                                             Yours sincerely\n                                             support <?cs var:defaults.company ?>\n	1
6	plain	English version of the e-mail is entered below the Czech version\n\nOznámení o vyřazení domény <?cs var:domain ?> z DNS\n\nVážený technický správce,\n\nvzhledem k tomu, že jste vedený jako technický kontakt u sady nameserverů\n<?cs var:nsset ?>, která je přiřazena k doménovému jménu <?cs var:domain ?>,\ndovolujeme si Vás upozornit, že toto doménové jméno bylo ke dni\n<?cs var:statechangedate ?> vyřazeno z DNS.\n\n\n                                             S pozdravem\n                                             podpora <?cs var:defaults.company ?>\n\n\n\nNotification about withdrawal of the domain <?cs var:domain ?> from DNS\n\nDear technical administrator,\n\nWith regard to the fact that you are named the technical contact for the set\n<?cs var:nsset ?> of nameservers, which is assigned to the <?cs var:domain ?>\ndomain name, we would like to notify you that the aforementioned domain name\nwas withdrawn from DNS as of <?cs var:statechangedate ?>.\n\n\n                                             Yours sincerely\n                                             support <?cs var:defaults.company ?>\n	1
7	plain	English version of the e-mail is entered below the Czech version\n\nOznámení o zrušení domény <?cs var:domain ?>\n\nVážený technický správce,\n\nvzhledem k tomu, že jste vedený jako technický kontakt u sady nameserverů\n<?cs var:nsset ?>, která je přiřazena k doménovému jménu <?cs var:domain ?>,\ndovolujeme si Vás upozornit, že toto doménové jméno bylo ke dni\n<?cs var:exregdate ?> zrušeno.\n\n\n                                             S pozdravem\n                                             podpora <?cs var:defaults.company ?>\n\n\n\nNotification about cancellation of the domain <?cs var:domain ?>\n\nDear technical administrator,\n\nWith regard to the fact that you are named the technical contact for the set\nof <?cs var:nsset ?> nameservers, which is assigned to the <?cs var:domain ?>\ndomain name, we would like to notify you that the aforementioned domain name\nwas cancelled as of <?cs var:exregdate ?>.\n\n\n                                             Yours sincerely\n                                             support <?cs var:defaults.company ?>\n	1
8	plain	English version of the e-mail is entered below the Czech version\n\nOznámení o blížícím se vypršení validace enum domény.\n\nVážený zákazníku,\n\ndovolujeme si Vás upozornit, že k <?cs var:checkdate ?> dosud nedošlo k prodloužení\nvalidace doménového jména <?cs var:domain ?>, která je platná do <?cs var:valdate ?>.\nV případě, že hodláte obnovit validaci uvedeného doménového jména, kontaktujte\nprosím svého registrátora a ve spolupráci s ním zajistěte prodloužení validace\nvašeho doménového jména před tímto datem.\n\nV této chvíli evidujeme následující údaje o doméně:\n\nDoménové jméno: <?cs var:domain ?>\nDržitel: <?cs var:owner ?>\nRegistrátor: <?cs var:registrar ?>\n<?cs each:item = administrators ?>Administrativní kontakt: <?cs var:item ?>\n<?cs /each ?>\n\n                                             S pozdravem\n                                             podpora <?cs var:defaults.company ?>\n\n\n\nNotification about approaching expiration of the enum domain validation\n\nDear customer,\n\nWe would like to notify you that as of <?cs var:checkdate ?>, extension of\nthe <?cs var:domain ?> domain name validation has not been made, yet.\nValidation will expire on <?cs var:valdate ?>. If you plan to renew validation\nof the aforementioned domain name, please, contact your registrar, and\ntogether execute the extension of validation of your domain name before\nthis date.\n\nAt this moment, we have the following information about the domain in our\nrecords:\n\nDomain name: <?cs var:domain ?>\nOwner: <?cs var:owner ?>\nRegistrar: <?cs var:registrar ?>\n<?cs each:item = administrators ?>Admin contact: <?cs var:item ?>\n<?cs /each ?>\n\n                                             Yours sincerely\n                                             support <?cs var:defaults.company ?>\n	1
9	plain	English version of the e-mail is entered below the Czech version\n\nOznámení o vypršení validace enum domény.\n\nVážený zákazníku,\n\ndovolujeme si Vás upozornit, že k <?cs var:checkdate ?> dosud nedošlo k prodloužení\nvalidace doménového jména <?cs var:domain ?>. Vzhledem k této skutečnosti\na na základě Pravidel registrace doménových jmen, ji <?cs var:defaults.company ?>\nvyřazuje ze zóny. Doménové jméno je i nadále registrováno. V případě, že\nhodláte obnovit validaci uvedeného doménového jména, kontaktujte prosím svého\nregistrátora a ve spolupráci s ním zajistěte prodloužení validace vašeho\ndoménového jména.\n\nV této chvíli evidujeme následující údaje o doméně:\n\nDoménové jméno: <?cs var:domain ?>\nDržitel: <?cs var:owner ?>\nRegistrátor: <?cs var:registrar ?>\n<?cs each:item = administrators ?>Administrativní kontakt: <?cs var:item ?>\n<?cs /each ?>\n\n                                             S pozdravem\n                                             podpora <?cs var:defaults.company ?>\n\n\n\nNotification about expiration of the enum domain validation\n\nDear customer,\n\nWe would like to notify you that as of <?cs var:checkdate ?>, extension of\nthe <?cs var:domain ?> domain name validation has not been made, yet.\nWith regard to this fact and in accordance with Rules for domain names\nregistrations, <?cs var:defaults.company ?> is withdrawing it from the zone. The domain\nname continues to be registered. If you plan to renew validation of the\naforementioned domain name, please, contact your registrar, and together\nexecute the extension of validation of your domain name.\n\nAt this moment, we have the following information about the domain in our\nrecords:\n\nDomain name: <?cs var:domain ?>\nOwner: <?cs var:owner ?>\nRegistrar: <?cs var:registrar ?>\n<?cs each:item = administrators ?>Admin contact: <?cs var:item ?>\n<?cs /each ?>\n\n\n                                             Yours sincerely\n                                             support <?cs var:defaults.company ?>\n	1
10	plain	<?cs def:typesubst(lang) ?><?cs if:lang == "cs" ?><?cs if:type == #3 ?>domény<?cs elif:type == #1 ?>kontaktu<?cs elif:type == #2 ?>sady nameserverů<?cs elif:type == #4 ?>sady klíčů<?cs /if ?><?cs elif:lang == "en" ?><?cs if:type == #3 ?>Domain<?cs elif:type == #1 ?>Contact<?cs elif:type == #2 ?>NS set<?cs elif:type == #4 ?>Keyset<?cs /if ?><?cs elif:lang == "ensmall" ?><?cs if:type == #3 ?>domain<?cs elif:type == #1 ?>contact<?cs elif:type == #2 ?>nsset<?cs elif:type == #4 ?>keyset<?cs /if ?><?cs /if ?><?cs /def ?>\n======================================================================\nOznámení o registraci / Registration notification\n======================================================================\nRegistrace <?cs call:typesubst("cs") ?> / <?cs call:typesubst("en") ?> create \nIdentifikátor <?cs call:typesubst("cs") ?> / <?cs call:typesubst("en") ?> handle : <?cs var:handle ?>\nČíslo žádosti / Ticket :  <?cs var:ticket ?>\nRegistrátor / Registrar : <?cs var:registrar ?>\n======================================================================\n\nŽádost byla úspěšně zpracována, požadovaná registrace byla provedena. \nThe request was completed successfully, required registration was done.<?cs if:type == #3 ?>\n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.<?cs /if ?>\n\nDetail <?cs call:typesubst("cs") ?> najdete na <?cs var:defaults.whoispage ?>?q=<?cs var:handle ?>\nFor detail information about <?cs call:typesubst("ensmall") ?> visit <?cs var:defaults.whoispage ?>?q=<?cs var:handle ?>\n\n\n                                             S pozdravem\n                                             podpora <?cs var:defaults.company ?>\n	1
11	plain	<?cs def:typesubst(lang) ?><?cs if:lang == "cs" ?><?cs if:type == #3 ?>domény<?cs elif:type == #1 ?>kontaktu<?cs elif:type == #2 ?>sady nameserverů<?cs elif:type == #4 ?>sady klíčů<?cs /if ?><?cs elif:lang == "en" ?><?cs if:type == #3 ?>Domain<?cs elif:type == #1 ?>Contact<?cs elif:type == #2 ?>NS set<?cs elif:type == #4 ?>Keyset<?cs /if ?><?cs elif:lang == "ensmall" ?><?cs if:type == #3 ?>domain<?cs elif:type == #1 ?>contact<?cs elif:type == #2 ?>nsset<?cs elif:type == #4 ?>keyset<?cs /if ?><?cs /if ?><?cs /def ?>\n\n<?cs def:print_value(which, varname) ?><?cs if:which == "old" ?><?cs set:lvarname = varname.old ?><?cs elif:which == "new" ?><?cs set:lvarname = varname.new ?><?cs /if ?><?cs alt:lvarname ?><?cs if:which == "old" ?>hodnota nenastavena / value not set<?cs elif:which == "new" ?>hodnota smazána / value deleted<?cs /if ?><?cs /alt ?><?cs /def ?>\n<?cs def:print_value_bool(which, varname, if_true, if_false) ?><?cs if:which == "old" ?><?cs set:lvarname = varname.old ?><?cs elif:which == "new" ?><?cs set:lvarname = varname.new ?><?cs /if ?><?cs if:lvarname == "1" ?><?cs var:if_true ?><?cs elif:lvarname == "0" ?><?cs var:if_false ?><?cs /if ?><?cs /def ?>\n<?cs def:print_value_list(which, varname, itemname) ?><?cs set:count = #1 ?><?cs each:item = varname ?><?cs var:itemname ?> <?cs var:count ?>: <?cs call:print_value(which, item) ?><?cs set:count = count + #1 ?>\n<?cs /each ?><?cs /def ?>\n\n<?cs def:value_list(which) ?><?cs if:changes.object.authinfo ?>Heslo / Authinfo: <?cs if:which == "old" ?>důvěrný údaj / private value<?cs elif:which == "new" ?>hodnota byla změněna / value was changed<?cs /if ?>\n<?cs /if ?><?cs if:type == #1 ?><?cs if:changes.contact.name ?>Jméno / Name: <?cs call:print_value(which, changes.contact.name) ?>\n<?cs /if ?><?cs if:changes.contact.org ?>Organizace / Organization: <?cs call:print_value(which, changes.contact.org) ?>\n<?cs /if ?><?cs if:changes.contact.address ?>Adresa / Address: <?cs call:print_value(which, changes.contact.address) ?>\n<?cs /if ?><?cs if:changes.contact.telephone ?>Telefon / Telephone: <?cs call:print_value(which, changes.contact.telephone) ?>\n<?cs /if ?><?cs if:changes.contact.fax ?>Fax / Fax: <?cs call:print_value(which, changes.contact.fax) ?>\n<?cs /if ?><?cs if:changes.contact.email ?>Email / Email: <?cs call:print_value(which, changes.contact.email) ?>\n<?cs /if ?><?cs if:changes.contact.notify_email ?>Notifikační email / Notify email: <?cs call:print_value(which, changes.contact.notify_email) ?>\n<?cs /if ?><?cs if:changes.contact.ident_type ?>Typ identifikace / Identification type: <?cs call:print_value(which, changes.contact.ident_type) ?>\n<?cs /if ?><?cs if:changes.contact.ident ?>Identifikační údaj / Identification data: <?cs call:print_value(which, changes.contact.ident) ?>\n<?cs /if ?><?cs if:changes.contact.vat ?>DIČ / VAT number: <?cs call:print_value(which, changes.contact.vat) ?>\n<?cs /if ?><?cs if:subcount(changes.contact.disclose) > #0 ?>Viditelnost údajů / Data visibility:\n<?cs if:changes.contact.disclose.name ?>  Jméno / Name: <?cs call:print_value_bool(which, changes.contact.disclose.name, "veřejné / public", "skryté / hidden") ?>\n<?cs /if ?><?cs if:changes.contact.disclose.org ?>  Organizace / Organization: <?cs call:print_value_bool(which, changes.contact.disclose.org, "veřejná / public", "skrytá / hidden") ?>\n<?cs /if ?><?cs if:changes.contact.disclose.email ?>  Email / Email: <?cs call:print_value_bool(which, changes.contact.disclose.email, "veřejný / public", "skrytý / hidden") ?>\n<?cs /if ?><?cs if:changes.contact.disclose.address ?>  Adresa / Address: <?cs call:print_value_bool(which, changes.contact.disclose.address, "veřejná / public", "skrytá / hidden") ?>\n<?cs /if ?><?cs if:changes.contact.disclose.notify_email ?>  Notifikační email / Notify email: <?cs call:print_value_bool(which, changes.contact.disclose.notify_email, "veřejný / public", "skrytý / hidden") ?>\n<?cs /if ?><?cs if:changes.contact.disclose.ident ?>  Identifikační údaj / Identification data: <?cs call:print_value_bool(which, changes.contact.disclose.ident, "veřejný / public", "skrytý / hidden") ?>\n<?cs /if ?><?cs if:changes.contact.disclose.vat ?>  DIČ / VAT number: <?cs call:print_value_bool(which, changes.contact.disclose.vat, "veřejné / public", "skryté / hidden") ?>\n<?cs /if ?><?cs if:changes.contact.disclose.telephone ?>  Telefon / Telephone: <?cs call:print_value_bool(which, changes.contact.disclose.telephone, "veřejný / public", "skrytý / hidden") ?>\n<?cs /if ?><?cs if:changes.contact.disclose.fax ?>  Fax / Fax: <?cs call:print_value_bool(which, changes.contact.disclose.fax, "veřejný / public", "skrytý / hidden") ?>\n<?cs /if ?><?cs /if ?><?cs elif:type == #2 ?><?cs if:changes.nsset.check_level ?>Úroveň tech. kontrol / Check level: <?cs call:print_value(which, changes.nsset.check_level) ?>\n<?cs /if ?><?cs if:changes.nsset.admin_c ?>Technické kontakty / Technical contacts: <?cs call:print_value(which, changes.nsset.admin_c) ?>\n<?cs /if ?><?cs if:subcount(changes.nsset.dns) > #0 ?><?cs call:print_value_list(which, changes.nsset.dns, "Jmenný server / Name server") ?>\n<?cs /if ?><?cs elif:type == #3 ?><?cs if:changes.domain.registrant ?>Držitel / Holder: <?cs call:print_value(which, changes.domain.registrant) ?>\n<?cs /if ?><?cs if:changes.domain.nsset ?>Sada jmenných serverů / Name server set: <?cs call:print_value(which, changes.domain.nsset) ?>\n<?cs /if ?><?cs if:changes.domain.keyset ?>Sada klíčů / Key set: <?cs call:print_value(which, changes.domain.keyset) ?>\n<?cs /if ?><?cs if:changes.domain.admin_c ?>Administrativní  kontakty / Administrative contacts: <?cs call:print_value(which, changes.domain.admin_c) ?>\n<?cs /if ?><?cs if:changes.domain.temp_c ?>Dočasné kontakty / Temporary contacts: <?cs call:print_value(which, changes.domain.temp_c) ?>\n<?cs /if ?><?cs if:changes.domain.val_ex_date ?>Validováno do / Validation expiration date: <?cs call:print_value(which, changes.domain.val_ex_date) ?>\n<?cs /if ?><?cs if:changes.domain.publish ?>Přidat do ENUM tel.sezn. / Include into ENUM dict: <?cs call:print_value_bool(which, changes.domain.publish, "ano / yes", "ne / no") ?>\n<?cs /if ?><?cs elif:type == #4 ?><?cs if:changes.keyset.admin_c ?>Technické kontakty / Technical contacts: <?cs call:print_value(which, changes.keyset.admin_c) ?>\n<?cs /if ?><?cs if:subcount(changes.keyset.ds) > #0 ?><?cs call:print_value_list(which, changes.keyset.ds, "DS záznam / DS record") ?>\n<?cs /if ?><?cs if:subcount(changes.keyset.dnskey) > #0 ?><?cs call:print_value_list(which, changes.keyset.dnskey, "DNS klíče / DNS keys") ?>\n<?cs /if ?><?cs /if ?><?cs /def ?>\n=====================================================================\nOznámení změn / Notification of changes \n=====================================================================\nZměna údajů <?cs call:typesubst("cs") ?> / <?cs call:typesubst("en") ?> data change \nIdentifikátor <?cs call:typesubst("cs") ?> / <?cs call:typesubst("en") ?> handle : <?cs var:handle ?>\nČíslo žádosti / Ticket :  <?cs var:ticket ?>\nRegistrátor / Registrar : <?cs var:registrar ?>\n=====================================================================\n \nŽádost byla úspěšně zpracována, <?cs if:changes == #1 ?>požadované změny byly provedeny<?cs else ?>žádná změna nebyla požadována, údaje zůstaly beze změny<?cs /if ?>.\nThe request was completed successfully, <?cs if:changes == #1 ?>required changes were done<?cs else ?>no changes were found in the request.<?cs /if ?>\n\n<?cs if:changes == #1 ?>\nPůvodní hodnoty / Original values:\n=====================================================================\n<?cs call:value_list("old") ?>\n\n\nNové hodnoty / New values:\n=====================================================================\n<?cs call:value_list("new") ?>\n\nOstatní hodnoty zůstaly beze změny. \nOther data wasn't modified.\n<?cs /if ?>\n\n\nÚplný detail <?cs call:typesubst("cs") ?> najdete na <?cs var:defaults.whoispage ?>?q=<?cs var:handle ?>\nFor full detail information about <?cs call:typesubst("ensmall") ?> visit <?cs var:defaults.whoispage ?>?q=<?cs var:handle ?>\n\n\n<?cs if:type == #1 ?>\nChcete mít snadnější přístup ke správě Vašich údajů? Založte si mojeID. Kromě \nnástroje, kterým můžete snadno a bezpečně spravovat údaje v centrálním \nregistru, získáte také prostředek pro jednoduché přihlašování k Vašim \noblíbeným webovým službám jediným jménem a heslem.\n<?cs /if ?>\n\n                                             S pozdravem\n                                             podpora <?cs var:defaults.company ?>\n	1
12	plain	<?cs def:typesubst(lang) ?><?cs if:lang == "cs" ?><?cs if:type == #3 ?>domény<?cs elif:type == #1 ?>kontaktu<?cs elif:type == #2 ?>sady nameserverů<?cs elif:type == #4 ?>sady klíčů<?cs /if ?><?cs elif:lang == "en" ?><?cs if:type == #3 ?>Domain<?cs elif:type == #1 ?>Contact<?cs elif:type == #2 ?>NS set<?cs elif:type == #4 ?>Keyset<?cs /if ?><?cs elif:lang == "ensmall" ?><?cs if:type == #3 ?>domain<?cs elif:type == #1 ?>contact<?cs elif:type == #2 ?>nsset<?cs elif:type == #4 ?>keyset<?cs /if ?><?cs /if ?><?cs /def ?>\n=====================================================================\nOznámení o transferu / Transfer notification\n=====================================================================\nTransfer <?cs call:typesubst("cs") ?> / <?cs call:typesubst("en") ?> transfer\nIdentifikátor <?cs call:typesubst("cs") ?> / <?cs call:typesubst("en") ?> handle : <?cs var:handle ?>\nČíslo žádosti / Ticket :  <?cs var:ticket ?>\nRegistrátor / Registrar : <?cs var:registrar ?>\n=====================================================================\n \nŽádost byla úspěšně zpracována, transfer byl proveden. \nThe request was completed successfully, transfer was completed. \n\nDetail <?cs call:typesubst("cs") ?> najdete na <?cs var:defaults.whoispage ?>?q=<?cs var:handle ?>\nFor detail information about <?cs call:typesubst("ensmall") ?> visit <?cs var:defaults.whoispage ?>?q=<?cs var:handle ?>\n\n\n                                             S pozdravem\n                                             podpora <?cs var:defaults.company ?>\n	1
13	plain	\n=====================================================================\nOznámení o prodloužení platnosti / Notification about renewal\n===================================================================== \nObnovení domény / Domain renew\nDomény / Domain : <?cs var:handle ?>\nČíslo žádosti / Ticket :  <?cs var:ticket ?>\nRegistrátor / Registrar : <?cs var:registrar ?>\n=====================================================================\n\nŽádost byla úspěšně zpracována, prodloužení platnosti bylo provedeno. \nThe request was completed successfully, domain was renewed. \n\nPři každé změně doporučujeme aktualizovat údaje o doméně, vyhnete se \ntak možným problémům souvisejícím s prodlužováním platnosti či manipulací \ns doménou osobami, které již nejsou oprávněny je provádět.\nUpdate domain data in the registry after any changes to avoid possible \nproblems with domain renewal or with domain manipulation done by persons \nwho are not authorized anymore.\n\nDetail domény najdete na <?cs var:defaults.whoispage ?>?q=<?cs var:handle ?>\nFor detail information about domain visit <?cs var:defaults.whoispage ?>?q=<?cs var:handle ?>\n\n\n                                             S pozdravem\n                                             podpora <?cs var:defaults.company ?>\n	1
14	plain	\n=====================================================================\nOznámení o zrušení / Delete notification \n=====================================================================\nVzhledem ke skutečnosti, že <?cs if:type == #1 ?>kontaktní osoba<?cs elif:type == #2 ?>sada nameserverů<?cs elif:type == #4 ?>sada klíčů<?cs /if ?> <?cs var:handle ?> \nnebyla po stanovenou dobu používána, <?cs var:defaults.company ?> \nruší ke dni <?cs var:deldate ?> uvedenou <?cs if:type == #1 ?>kontaktní osobu<?cs elif:type == #2 ?>sadu nameserverů<?cs elif:type == #4 ?>sadu klíčů<?cs /if ?>.\n\nZrušení <?cs if:type == #1 ?>kontaktní osoby<?cs elif:type == #2 ?>sady nameserverů<?cs elif:type == #4 ?>sady klíčů<?cs /if ?> nemá žádný vliv na funkčnost Vašich \nzaregistrovaných doménových jmen.\n\nWith regard to the fact that the <?cs if:type == #1 ?>contact<?cs elif:type == #2 ?>NS set<?cs elif:type == #4 ?>keyset<?cs /if ?> <?cs var:handle ?>\nwas not used during the fixed period, <?cs var:defaults.company ?>\nis cancelling the aforementioned <?cs if:type == #1 ?>contact<?cs elif:type == #2 ?>set of nameservers<?cs elif:type == #4 ?>set of keysets<?cs /if ?> as of <?cs var:deldate ?>.\n\nCancellation of <?cs if:type == #1 ?>contact<?cs elif:type == #2 ?>NS set<?cs elif:type == #4 ?>Keyset<?cs /if ?> has no influence on functionality of your\nregistred domains.\n=====================================================================\n\n\n                                             S pozdravem\n                                             podpora <?cs var:defaults.company ?>\n	1
15	plain	<?cs def:typesubst(lang) ?><?cs if:lang == "cs" ?><?cs if:type == #3 ?>domény<?cs elif:type == #1 ?>kontaktu<?cs elif:type == #2 ?>sady nameserverů<?cs elif:type == #4 ?>sady klíčů<?cs /if ?><?cs elif:lang == "en" ?><?cs if:type == #3 ?>Domain<?cs elif:type == #1 ?>Contact<?cs elif:type == #2 ?>NS set<?cs elif:type == #4 ?>Keyset<?cs /if ?><?cs /if ?><?cs /def ?>\n=====================================================================\nOznámení o zrušení / Delete notification \n=====================================================================\nZrušení <?cs call:typesubst("cs") ?> / <?cs call:typesubst("en") ?> deletion\nIdentifikator <?cs call:typesubst("cs") ?> / <?cs call:typesubst("en") ?> handle : <?cs var:handle ?>\nCislo zadosti / Ticket :  <?cs var:ticket ?>\nRegistrator / Registrar : <?cs var:registrar ?>\n=====================================================================\n \nŽádost byla úspěšně zpracována, požadované zrušení bylo provedeno. \nThe request was completed successfully, required delete was done. \n \n=====================================================================\n\n\n                                             S pozdravem\n                                             podpora <?cs var:defaults.company ?>\n	1
16	plain	\nVýsledek technické kontroly sady nameserverů <?cs var:handle ?>\nResult of technical check on NS set <?cs var:handle ?>\n\nDatum kontroly / Date of the check: <?cs var:checkdate ?>\nTyp kontroly / Control type : periodická / periodic \nČíslo kontroly / Ticket: <?cs var:ticket ?>\n\n<?cs def:printtest(par_test) ?><?cs if:par_test.name == "existence" ?>Následující nameservery v sadě nameserverů nejsou dosažitelné:\nFollowing nameservers in NS set are not reachable:\n<?cs each:ns = par_test.ns ?>    <?cs var:ns ?>\n<?cs /each ?><?cs /if ?><?cs if:par_test.name == "autonomous" ?>Sada nameserverů neobsahuje minimálně dva nameservery v různých\nautonomních systémech.\nIn NS set are no two nameservers in different autonomous systems.\n\n<?cs /if ?><?cs if:par_test.name == "presence" ?><?cs each:ns = par_test.ns ?>Nameserver <?cs var:ns ?> neobsahuje záznam pro domény:\nNameserver <?cs var:ns ?> does not contain record for domains:\n<?cs each:fqdn = ns.fqdn ?>    <?cs var:fqdn ?>\n<?cs /each ?><?cs if:ns.overfull ?>    ...\n<?cs /if ?><?cs /each ?><?cs /if ?><?cs if:par_test.name == "authoritative" ?><?cs each:ns = par_test.ns ?>Nameserver <?cs var:ns ?> není autoritativní pro domény:\nNameserver <?cs var:ns ?> is not authoritative for domains:\n<?cs each:fqdn = ns.fqdn ?>    <?cs var:fqdn ?>\n<?cs /each ?><?cs if:ns.overfull ?>    ...\n<?cs /if ?><?cs /each ?><?cs /if ?><?cs if:par_test.name == "heterogenous" ?>Všechny nameservery v sadě nameserverů používají stejnou implementaci\nDNS serveru.\nAll nameservers in NS set use the same implementation of DNS server.\n\n<?cs /if ?><?cs if:par_test.name == "notrecursive" ?>Následující nameservery v sadě nameserverů jsou rekurzivní:\nFollowing nameservers in NS set are recursive:\n<?cs each:ns = par_test.ns ?>    <?cs var:ns ?>\n<?cs /each ?><?cs /if ?><?cs if:par_test.name == "notrecursive4all" ?>Následující nameservery v sadě nameserverů zodpověděly rekurzivně dotaz:\nFollowing nameservers in NS set answered recursively a query:\n<?cs each:ns = par_test.ns ?>    <?cs var:ns ?>\n<?cs /each ?><?cs /if ?><?cs if:par_test.name == "dnsseckeychase" ?>Pro následující domény přislušející sadě nameserverů nebylo možno\nověřit validitu DNSSEC podpisu:\nFor following domains belonging to NS set was unable to validate\nDNSSEC signature:\n<?cs each:domain = par_test.ns ?>    <?cs var:domain ?>\n<?cs /each ?><?cs /if ?><?cs /def ?>\n=== Chyby / Errors ==================================================\n\n<?cs each:item = tests ?><?cs if:item.type == "error" ?><?cs call:printtest(item) ?><?cs /if ?><?cs /each ?>\n=== Varování / Warnings =============================================\n\n<?cs each:item = tests ?><?cs if:item.type == "warning" ?><?cs call:printtest(item) ?><?cs /if ?><?cs /each ?>\n=== Upozornění / Notice =============================================\n\n<?cs each:item = tests ?><?cs if:item.type == "notice" ?><?cs call:printtest(item) ?><?cs /if ?><?cs /each ?>\n=====================================================================\n\n\n                                             S pozdravem\n                                             podpora <?cs var:defaults.company ?>\n	1
17	plain	English version of the e-mail is entered below the Czech version\n\nZaslání potvrzení o přijaté záloze\n\nVážený obchodní přátelé,\n\n  v příloze zasíláme daňový doklad na přijatou zálohu pro zónu <?cs var:zone ?>. Tento daňový doklad \nslouží k uplatnění nároku na odpočet DPH přijaté zálohy\n\n                                             S pozdravem\n                                             podpora <?cs var:defaults.company ?>\n\n\n\nAccepted Advance Payment Confirmation\n\nDear business partners,\n\n  Enclosed with this letter, we are sending a tax document for the advance\npayment accepted for the zone <?cs var:zone ?>. This tax document can be used to claim VAT deduction for\nthe advance payment.\n\n                                             Yours sincerely\n                                             support <?cs var:defaults.company ?>\n	1
18	plain	English version of the e-mail is entered below the Czech version\n\nZaslání měsíčního vyúčtování\n\nVážený obchodní přátelé,\n\n  v příloze zasíláme daňový doklad za služby registrací doménových jmen a \nudržování záznamů o doménových jménech za období od <?cs var:fromdate ?>\ndo <?cs var:todate ?> pro zónu <?cs var:zone ?>.\n\n                                             S pozdravem\n                                             podpora <?cs var:defaults.company ?>\n\n\n\nMonthly Bill Dispatching\n\nDear business partners,\n\n  Enclosed with this letter, we are sending a tax document for the domain name\nregistration services and the maintenance of domain name records for the period\nfrom <?cs var:fromdate ?> to <?cs var:todate ?> for the zone <?cs var:zone ?>.\n\n                                             Yours sincerely\n                                             support <?cs var:defaults.company ?>\n	1
19	plain	English version of the e-mail is entered below the Czech version\n\nZaslání měsíčního vyúčtování\n\nVážený obchodní přátelé,\n\n  jelikož v období od <?cs var:fromdate ?> do <?cs var:todate ?> v zóně <?cs var:zone ?> Vaše společnost neprovedla\nžádnou registraci doménového jména ani prodloužení platnosti doménového\njména a nedošlo tak k čerpání žádných placených služeb, nebude pro toto\nobdobí vystaven daňový doklad.\n\n                                             S pozdravem\n                                             podpora <?cs var:defaults.company ?>\n\n\n\nMonthly Bill Dispatching\n\nDear business partners,\n\n  Since your company has not performed any domain name registration or domain\nname validity extension in the period from <?cs var:fromdate ?> to <?cs var:todate ?> for the zone <?cs var:zone ?>,\nhence not drawing any paid services, no tax document will be issued for this\nperiod.\n\n                                             Yours sincerely\n                                             support <?cs var:defaults.company ?>\n	1
20	plain	English version of the e-mail is entered below the Czech version\n\nInformace o vyřízení žádosti\n\nVážený zákazníku,\n\n   na základě Vaší žádosti podané prostřednictvím webového formuláře\nna stránkách sdružení dne <?cs var:reqdate ?>, které bylo přiděleno identifikační \nčíslo <?cs var:reqid ?>, Vám oznamujeme, že požadovaná žádost o <?cs if:otype == #1 ?>zablokování<?cs elif:otype == #2 ?>odblokování<?cs /if ?>\n<?cs if:rtype == #1 ?>změny dat<?cs elif:rtype == #2 ?>transferu k jinému registrátorovi<?cs /if ?> pro <?cs if:type == #3 ?>doménu<?cs elif:type == #1 ?>kontakt s identifikátorem<?cs elif:type == #2 ?>sadu nameserverů s identifikátorem<?cs elif:type == #4 ?>sadu klíčů s identifikátorem<?cs /if ?> <?cs var:handle ?> \nbyla úspěšně realizována.  \n<?cs if:otype == #1 ?>\nU <?cs if:type == #3 ?>domény<?cs elif:type == #1 ?>kontaktu s identifikátorem<?cs elif:type == #2 ?>sady nameserverů s identifikátorem<?cs elif:type == #4 ?>sady klíčů s identifikátorem<?cs /if ?> <?cs var:handle ?> nebude možné provést \n<?cs if:rtype == #1 ?>změnu dat<?cs elif:rtype == #2 ?>transfer k jinému registrátorovi <?cs /if ?> až do okamžiku, kdy tuto blokaci \nzrušíte pomocí příslušného formuláře na stránkách sdružení.\n<?cs /if?>\n                                             S pozdravem\n                                             podpora <?cs var:defaults.company ?>\n\nInformation about processing of request\n\nDear customer,\n\n   based on your request submitted via the web form on the association\npages on <?cs var:reqdate ?>, which received the identification number \n<?cs var:reqid ?>, we are announcing that your request for <?cs if:otype == #1 ?>blocking<?cs elif:otype == #2 ?>unblocking<?cs /if ?>\n<?cs if:rtype == #1 ?>data changes<?cs elif:rtype == #2 ?>transfer to other registrar<?cs /if ?> for <?cs if:type == #3 ?>domain name<?cs elif:type == #1 ?>contact with identifier<?cs elif:type == #2 ?>NS set with identifier<?cs elif:type == #4 ?>Keyset with identifier<?cs /if ?> <?cs var:handle ?> \nhas been realized.\n<?cs if:otype == #1 ?>\nNo <?cs if:rtype == #1 ?>data changes<?cs elif:rtype == #2 ?>transfer to other registrar<?cs /if ?> of <?cs if:type == #3 ?>domain name<?cs elif:type == #1 ?>contact with identifier<?cs elif:type == #2 ?>NS set with identifier<?cs elif:type == #4 ?>Keyset with identifier<?cs /if ?> <?cs var:handle ?> \nwill be possible until you cancel the blocking option using the \napplicable form on association pages. \n<?cs /if?>\n                                             Yours sincerely\n                                             support <?cs var:defaults.company ?>\n	1
21	plain	\nVážený uživateli,\n\ntento e-mail potvrzuje úspěšné založení účtu mojeID s těmito údaji:\n\núčet mojeID: <?cs var:handle ?>\njméno:       <?cs var:firstname ?>\npříjmení:    <?cs var:lastname ?>\ne-mail:      <?cs var:email ?>\n\nPro aktivaci Vašeho účtu je nutné vložit kódy PIN1 a PIN2.\n\nPIN1: <?cs var:passwd ?>\nPIN2: Vám byl zaslán pomocí SMS.\n\nAktivaci účtu proveďte kliknutím na následující odkaz:\n\nhttps://<?cs var:hostname ?>/identify/email-sms/<?cs var:identification ?>/?password1=<?cs var:passwd ?>\n\nVáš tým <?cs var:defaults.company ?>\n	1
22	plain	\n<?cs if:status == #1 ?>\nNa základě žádosti číslo <?cs var:reqid ?> ze dne <?cs var:reqdate ?> byla provedena validace účtu mojeID.<?cs else ?>\nVáš účet mojeID:<?cs /if ?>\n\nJméno : <?cs var:name ?><?cs if:org ?>\nOrganizace : <?cs var:org ?><?cs /if ?><?cs if:ic ?>\nIČ : <?cs var:ic ?><?cs /if ?><?cs if:birthdate ?>\nDatum narození : <?cs var:birthdate ?><?cs /if ?>\nAdresa : <?cs var:address ?>\n<?cs if:status != #1 ?>\nu kterého bylo požádáno o validaci žádostí číslo <?cs var:reqid ?> ze dne <?cs var:reqdate ?> nebyl validován.\n<?cs /if ?>\nVáš tým <?cs var:defaults.company ?>\n	1
24	plain	Vážený uživateli,\n\nk dokončení procedury změny emailu zadejte prosím kód PIN1: <?cs var:pin ?>\n\nVáš tým CZ.NIC	1
27	plain	\nVážený uživateli,\n\ntento e-mail potvrzuje úspěšné založení účtu mojeID s těmito údaji:\n\núčet mojeID: <?cs var:handle ?>\njméno:       <?cs var:firstname ?>\npříjmení:    <?cs var:lastname ?>\ne-mail:      <?cs var:email ?>\n\nPro aktivaci Vašeho účtu je nutné vložit kód PIN1.\n\nPIN1: <?cs var:passwd ?>\n\nAktivaci účtu proveďte kliknutím na následující odkaz:\n\nhttps://<?cs var:hostname ?>/identify/email/<?cs var:identification ?>/?password1=<?cs var:passwd ?>\n\nVáš tým <?cs var:defaults.company ?>\n	1
23	plain	\nThis is a bilingual message. Please see below for the English version\n\nVážená paní, vážený pane,\n\ndovolujeme si Vás zdvořile požádat o kontrolu správnosti údajů,\nkteré nyní evidujeme u Vašeho kontaktu v centrálním registru\ndoménových jmen.\n\nID kontaktu v registru: <?cs var:handle ?>\nOrganizace: <?cs var:organization ?>\nJméno: <?cs var:name ?>\nAdresa: <?cs var:address ?><?cs if:ident_type != "" ?>\n<?cs if:ident_type == "RC"?>Datum narození: <?cs \nelif:ident_type == "OP"?>Číslo OP: <?cs \nelif:ident_type == "PASS"?>Číslo pasu: <?cs \nelif:ident_type == "ICO"?>IČO: <?cs \nelif:ident_type == "MPSV"?>Identifikátor MPSV: <?cs \nelif:ident_type == "BIRTHDAY"?>Datum narození: <?cs \n/if ?> <?cs var:ident_value ?><?cs \n/if ?>\nDIČ: <?cs var:dic ?>\nTelefon: <?cs var:telephone ?>\nFax: <?cs var:fax ?>\nE-mail: <?cs var:email ?>\nNotifikační e-mail: <?cs var:notify_email ?>\nUrčený registrátor: <?cs var:registrar_name ?> (<?cs var:registrar_url ?>)\n<?cs if:registrar_memo_cz ?>Další informace poskytnuté registrátorem:\n<?cs var:registrar_memo_cz ?><?cs /if ?>\n\nSe žádostí o opravu údajů se neváhejte obrátit na svého vybraného registrátora.\nV případě, že zde uvedené údaje odpovídají skutečnosti, není nutné na tuto zprávu reagovat.\n\nAktuální, úplné a správné informace v registru znamenají Vaši jistotu,\nže Vás důležité informace o Vaší doméně zastihnou vždy a včas na správné adrese.\nNedočkáte se tak nepříjemného překvapení v podobě nefunkční či zrušené domény.\n\nDovolujeme si Vás rovněž upozornit, že nesprávné, nepravdivé, neúplné\nči zavádějící údaje mohou být v souladu s Pravidly registrace doménových jmen\nv ccTLD .cz důvodem ke zrušení registrace doménového jména!\n\nÚplný výpis z registru obsahující všechny domény a další objekty přiřazené\nk shora uvedenému kontaktu naleznete v příloze.\n\nVáš tým CZ.NIC.\n\nPříloha:\n\n<?cs if:domains.0 ?>Seznam domén kde je kontakt v roli držitele nebo administrativního\nkontaktu:<?cs each:item = domains ?>\n<?cs var:item ?><?cs /each ?><?cs else ?>Kontakt není uveden u žádného doménového jména.<?cs /if ?><?cs if:nssets.0 ?>\n\nSeznam sad jmenných serverů, kde je kontakt v roli technického kontaktu:<?cs each:item = nssets ?>\n<?cs var:item ?><?cs /each ?><?cs /if ?><?cs if:keysets.0 ?>\n\nSeznam sad klíčů, kde je kontakt v roli technického kontaktu:<?cs each:item = keysets ?>\n<?cs var:item ?><?cs /each ?><?cs /if ?>\n\n\n\nDear Sir or Madam,\n\nPlease check the correctness of the information we currently have on file\nfor your contact in the central registry of domain names.\n\nContact ID in the registry: <?cs var:handle ?>\nOrganization: <?cs var:organization ?>\nName: <?cs var:name ?>\nAddress: <?cs var:address ?><?cs if:ident_type != "" ?>\n<?cs if:ident_type == "RC"?>Birth date: <?cs \nelif:ident_type == "OP"?>Personal ID: <?cs \nelif:ident_type == "PASS"?>Passport number: <?cs \nelif:ident_type == "ICO"?>ID number: <?cs \nelif:ident_type == "MPSV"?>MSPV ID: <?cs \nelif:ident_type == "BIRTHDAY"?>Birth day: <?cs \n/if ?> <?cs var:ident_value ?><?cs \n/if ?>\nVAT No.: <?cs var:dic ?>\nPhone: <?cs var:telephone ?>\nFax: <?cs var:fax ?>\nE-mail: <?cs var:email ?>\nNotification e-mail: <?cs var:notify_email ?>\nDesignated registrator: <?cs var:registrar_name ?> (<?cs var:registrar_url ?>)\n<?cs if:registrar_memo_en ?>Other information provided by registrar:\n<?cs var:registrar_memo_en ?><?cs /if ?>\n\nDo not hesitate to contact your designated registrar with a correction request.\n\nHaving up-to-date, complete and correct information in the registry is crucial\nto reach you with all the important information about your domain name in a timely manner\nand at the correct contact address. Check you contact details now and avoid unpleasant\nsurprises such as a non-functional or expired domain.\n\nWe would also like to inform you that in accordance with the Rules of Domain Name\nRegistration for the .cz ccTLD, incorrect, false, incomplete or misleading\ninformation can be grounds for the cancellation of a domain name registration.\n\nPlease do not hesitate to contact us for additional information.\n\nYou can find a complete summary of your domain names, and other objects\nassociated with your contact attached below.\n\n\nYour CZ.NIC team.\n\nAttachment:\n\n<?cs if:domains.0 ?>Domains where the contact is a holder or an administrative contact:<?cs each:item = domains ?>\n<?cs var:item ?><?cs /each ?><?cs else ?>Contact is not linked to any domain name.<?cs /if ?><?cs if:nssets.0 ?>\n\nSets of name servers where the contact is a technical contact:<?cs each:item = nssets ?>\n<?cs var:item ?><?cs /each ?><?cs /if ?><?cs if:keysets.0 ?>\n\nKeysets where the contact is a technical contact:<?cs each:item = keysets ?>\n<?cs var:item ?><?cs /each ?><?cs /if ?>\n	1
25	plain	\nEnglish version of the e-mail is entered below the Czech version\n\nVážený uživateli,\n\ntento e-mail potvrzuje úspěšné zahájení procesu ověření kontaktu v Centrálním registru:\n\nID kontaktu: <?cs var:handle ?>\njméno:       <?cs var:firstname ?>\npříjmení:    <?cs var:lastname ?>\ne-mail:      <?cs var:email ?>\n\nPro dokončení prvního ze dvou kroků ověření je nutné zadat kódy PIN1 a PIN2.\n\nPIN1: <?cs var:passwd ?>\nPIN2: Vám byl zaslán pomocí SMS.\n\nZadání PIN1 a PIN2 bude možné po kliknutí na následující odkaz:\nhttps://<?cs var:hostname ?>/verification/identify/email-sms/<?cs var:identification ?>/?password1=<?cs var:passwd ?>\n\nVáš tým <?cs var:defaults.company ?>\n\n\n\nDear User,\n\nThis e-mail confirms that the process of verifying your contact data in the central registry has been successfully initiated:\n\ncontact ID: <?cs var:handle ?>\nfirst name: <?cs var:firstname ?>\nlast name:  <?cs var:lastname ?>\ne-mail:     <?cs var:email ?>\n\nTo complete the first of the two verification steps, authorisation with your PIN1 and PIN2 codes is required.\n\nPIN1: <?cs var:passwd ?>\nPIN2: was sent to you by a text message (SMS).\n\nYou will be able to enter your PIN1 and PIN2 by following this link:\nhttps://<?cs var:hostname ?>/verification/identify/email-sms/<?cs var:identification ?>/?password1=<?cs var:passwd ?>\n\nYour <?cs var:defaults.company ?> team\n	1
26	plain	\nEnglish version of the e-mail is entered below the Czech version\n\nVážený uživateli,\n\nprvní část ověření kontaktu v Centrálním registru je úspěšně za Vámi.\n\nidentifikátor: <?cs var:handle ?>\njméno:         <?cs var:firstname ?>\npříjmení:      <?cs var:lastname ?>\ne-mail:        <?cs var:email ?>\n\nV nejbližších dnech ještě očekávejte zásilku s kódem PIN3, jehož pomocí\nověříme Vaši poštovní adresu. Zadáním kódu PIN3 do formuláře na stránce\nhttps://<?cs var:hostname ?>/verification/identify/letter/?handle=<?cs var:handle ?>\ndokončíte proces ověření kontaktu.\n\nRádi bychom Vás také upozornili, že až do okamžiku zadání kódu PIN3\nnelze údaje v kontaktu měnit. Případná editace údajů v této fázi\nověřovacího procesu by měla za následek jeho přerušení.\n\nDěkujeme za pochopení.\n\nVáš tým <?cs var:defaults.company ?>\n\n\n\nDear User,\n\nThe first step of the verification of the central registry contact details provided below\nhas been successfully completed.\n\ncontact ID: <?cs var:handle ?>\nfirst name: <?cs var:firstname ?>\nlast name:  <?cs var:lastname ?>\ne-mail:     <?cs var:email ?>\n\nYour PIN3 has now also been generated; you will receive it by mail within a few days\nat the address listed in the contact.\n\nVerification of this contact will be complete once you enter your PIN3\ninto the corresponding field at this address:\nhttps://<?cs var:hostname ?>/verification/identify/letter/?handle=<?cs var:handle ?>\n\nYour <?cs var:defaults.company ?> team\n	1
\.


--
-- Data for Name: mail_type; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY mail_type (id, name, subject) FROM stdin;
1	sendauthinfo_pif	Zaslání autorizační informace / Sending authorization information
2	sendauthinfo_epp	Zaslání autorizační informace / Sending authorization information
3	expiration_notify	Upozornění na nutnost úhrady domény <?cs var:domain ?> / Reminder of the need to settle fees for the domain <?cs var:domain ?>
4	expiration_dns_owner	Oznámení o vyřazení domény <?cs var:domain ?> z DNS / Notification about inactivation of the domain <?cs var:domain ?> from DNS
5	expiration_register_owner	Oznámení o zrušení domény <?cs var:domain ?> / Notification about cancellation of the domain <?cs var:domain ?>
6	expiration_dns_tech	Oznámení o vyřazení domény <?cs var:domain ?> z DNS / Notification about withdrawal of the domain <?cs var:domain ?> from DNS
7	expiration_register_tech	Oznámení o zrušení domény <?cs var:domain ?> / Notification about cancellation of the domain <?cs var:domain ?>
8	expiration_validation_before	Oznámení vypršení validace enum domény <?cs var:domain ?> / Notification about expiration of the enum domain <?cs var:domain ?> validation
9	expiration_validation	Oznámení o vypršení validace enum domény <?cs var:domain ?> / Notification about expiration of the enum domain <?cs var:domain ?> validation
10	notification_create	<?cs def:typesubst(lang) ?><?cs if:lang == "cs" ?><?cs if:type == #3 ?>domény<?cs elif:type == #1 ?>kontaktu<?cs elif:type == #2 ?>sady nameserverů<?cs elif:type == #4 ?>sady klíčů<?cs /if ?><?cs elif:lang == "en" ?><?cs if:type == #3 ?>Domain<?cs elif:type == #1 ?>Contact<?cs elif:type == #2 ?>NS set<?cs elif:type == #4 ?>Keyset<?cs /if ?><?cs /if ?><?cs /def ?>Oznámení o registraci <?cs call:typesubst("cs") ?> <?cs var:handle ?> / <?cs call:typesubst("en") ?> <?cs var:handle ?> registration notification
11	notification_update	<?cs def:typesubst(lang) ?><?cs if:lang == "cs" ?><?cs if:type == #3 ?>domény<?cs elif:type == #1 ?>kontaktu<?cs elif:type == #2 ?>sady nameserverů<?cs elif:type == #4 ?>sady klíčů<?cs /if ?><?cs elif:lang == "en" ?><?cs if:type == #3 ?>domain<?cs elif:type == #1 ?>contact<?cs elif:type == #2 ?>NS set<?cs elif:type == #4 ?>keyset<?cs /if ?><?cs /if ?><?cs /def ?>Oznámení změn <?cs call:typesubst("cs") ?> <?cs var:handle ?>/ Notification of <?cs call:typesubst("en") ?> <?cs var:handle ?> changes
12	notification_transfer	<?cs def:typesubst(lang) ?><?cs if:lang == "cs" ?><?cs if:type == #3 ?>domény<?cs elif:type == #1 ?>kontaktu<?cs elif:type == #2 ?>sady nameserverů<?cs elif:type == #4 ?>sady klíčů<?cs /if ?><?cs elif:lang == "en" ?><?cs if:type == #3 ?>Domain<?cs elif:type == #1 ?>Contact<?cs elif:type == #2 ?>NS set<?cs elif:type == #4 ?>Keyset<?cs /if ?><?cs /if ?><?cs /def ?>Oznámení o transferu <?cs call:typesubst("cs") ?> <?cs var:handle ?> / <?cs call:typesubst("en") ?> <?cs var:handle ?> transfer notification
13	notification_renew	Oznámení o prodloužení platnosti domény <?cs var:handle ?> / Domain name <?cs var:handle ?> renew notification
14	notification_unused	<?cs def:typesubst(lang) ?><?cs if:lang == "cs" ?><?cs if:type == #3 ?>domény<?cs elif:type == #1 ?>kontaktu<?cs elif:type == #2 ?>sady nameserverů<?cs elif:type == #4 ?>sady klíčů<?cs /if ?><?cs elif:lang == "en" ?><?cs if:type == #3 ?>Domain<?cs elif:type == #1 ?>Contact<?cs elif:type == #2 ?>NS set<?cs elif:type == #4 ?>Keyset<?cs /if ?><?cs /if ?><?cs /def ?>Oznámení o zrušení <?cs call:typesubst("cs") ?> <?cs var:handle ?> / <?cs call:typesubst("en") ?> <?cs var:handle ?> delete notification
15	notification_delete	<?cs def:typesubst(lang) ?><?cs if:lang == "cs" ?><?cs if:type == #3 ?>domény<?cs elif:type == #1 ?>kontaktu<?cs elif:type == #2 ?>sady nameserverů<?cs elif:type == #4 ?>sady klíčů<?cs /if ?><?cs elif:lang == "en" ?><?cs if:type == #3 ?>Domain<?cs elif:type == #1 ?>Contact<?cs elif:type == #2 ?>NS set<?cs elif:type == #4 ?>Keyset<?cs /if ?><?cs /if ?><?cs /def ?>Oznámení o zrušení <?cs call:typesubst("cs") ?> <?cs var:handle ?> / <?cs call:typesubst("en") ?> <?cs var:handle ?> delete notification
16	techcheck	Výsledek technického testu / Technical check result
17	invoice_deposit	Přijatá záloha / Accepted advance payment
18	invoice_audit	Měsíční vyúčtování / Monthly billing
19	invoice_noaudit	Měsíční vyúčtování / Monthly billing
20	request_block	Informace o vyřízení žádosti / Information about processing of request
21	mojeid_identification	Založení účtu mojeID
22	mojeid_validation	Validace účtu mojeID <?cs if:status == #1 ?>provedena<?cs else ?>neprovedena<?cs /if ?>
24	mojeid_email_change	MojeID - změna emailu
27	mojeid_verified_contact_transfer	Založení účtu mojeID
23	annual_contact_reminder	Ověření správnosti údajů
25	conditional_contact_identification	Podmíněná identifikace kontaktu
26	contact_identification	Identifikace kontaktu
\.


--
-- Data for Name: mail_type_template_map; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY mail_type_template_map (typeid, templateid) FROM stdin;
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
24	24
27	27
23	23
25	25
26	26
\.


--
-- Data for Name: mail_vcard; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY mail_vcard (vcard, id) FROM stdin;
BEGIN:VCARD\nVERSION:2.1\nN:podpora CZ. NIC, z.s.p.o.\nFN:podpora CZ. NIC, z.s.p.o.\nORG:CZ.NIC, z.s.p.o.\nTITLE:zákaznická podpora\nTEL;WORK;VOICE:+420 222 745 111\nTEL;WORK;FAX:+420 222 745 112\nADR;WORK:;;Americká 23;Praha 2;;120 00;Česká republika\nURL;WORK:http://www.nic.cz\nEMAIL;PREF;INTERNET:podpora@nic.cz\nREV:20070403T143928Z\nEND:VCARD\n	1
\.


--
-- Data for Name: message; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY message (id, clid, crdate, exdate, seen, msgtype) FROM stdin;
\.


--
-- Data for Name: message_archive; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY message_archive (id, crdate, moddate, attempt, status_id, comm_type_id, message_type_id) FROM stdin;
\.


--
-- Data for Name: message_contact_history_map; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY message_contact_history_map (id, contact_object_registry_id, contact_history_historyid, message_archive_id) FROM stdin;
\.


--
-- Data for Name: message_type; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY message_type (id, type) FROM stdin;
1	domain_expiration
2	mojeid_pin2
3	mojeid_pin3
4	mojeid_sms_change
5	monitoring
6	contact_verification_pin2
7	contact_verification_pin3
\.


--
-- Data for Name: messagetype; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY messagetype (id, name) FROM stdin;
1	credit
2	techcheck
3	transfer_contact
4	transfer_nsset
5	transfer_domain
6	delete_contact
7	delete_nsset
8	delete_domain
9	imp_expiration
10	expiration
11	imp_validation
12	validation
13	outzone
14	transfer_keyset
15	delete_keyset
16	request_fee_info
\.


--
-- Data for Name: notify_letters; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY notify_letters (state_id, letter_id) FROM stdin;
\.


--
-- Data for Name: notify_request; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY notify_request (request_id, message_id) FROM stdin;
\.


--
-- Data for Name: notify_statechange; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY notify_statechange (state_id, type, mail_id) FROM stdin;
\.


--
-- Data for Name: notify_statechange_map; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY notify_statechange_map (id, state_id, obj_type, mail_type_id, emails) FROM stdin;
1	9	3	3	1
2	20	3	4	1
3	17	3	5	1
4	17	2	14	1
5	17	1	14	1
6	20	3	6	2
7	17	3	7	2
8	12	3	8	1
9	13	3	9	1
10	13	3	6	2
11	17	4	14	1
12	20	3	4	3
\.


--
-- Data for Name: nsset; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY nsset (id, checklevel) FROM stdin;
8	3
9	3
10	3
11	3
12	3
13	3
14	3
15	3
16	3
17	3
\.


--
-- Data for Name: nsset_contact_map; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY nsset_contact_map (nssetid, contactid) FROM stdin;
8	6
8	4
9	6
9	4
10	6
10	4
11	6
11	4
12	6
12	4
13	6
13	4
14	6
14	4
15	6
15	4
16	6
16	4
17	6
17	4
\.


--
-- Data for Name: nsset_contact_map_history; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY nsset_contact_map_history (historyid, nssetid, contactid) FROM stdin;
8	8	6
8	8	4
9	9	6
9	9	4
10	10	6
10	10	4
11	11	6
11	11	4
12	12	6
12	12	4
13	13	6
13	13	4
14	14	6
14	14	4
15	15	6
15	15	4
16	16	6
16	16	4
17	17	6
17	17	4
\.


--
-- Data for Name: nsset_history; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY nsset_history (historyid, id, checklevel) FROM stdin;
8	8	3
9	9	3
10	10	3
11	11	3
12	12	3
13	13	3
14	14	3
15	15	3
16	16	3
17	17	3
\.


--
-- Data for Name: object; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY object (id, clid, upid, trdate, update, authinfopw) FROM stdin;
1	1	\N	\N	\N	RxuiIlbd
2	1	\N	\N	\N	ANuUSKZg
3	1	\N	\N	\N	NKekVvom
4	1	\N	\N	\N	AdfYsvDa
5	1	\N	\N	\N	KHmxphcy
6	1	\N	\N	\N	sMtuUAze
7	1	\N	\N	\N	PNhmLTYQ
8	1	\N	\N	\N	TrgdMfXu
9	1	\N	\N	\N	hfqiNFVJ
10	1	\N	\N	\N	KLachdTl
11	1	\N	\N	\N	pYmSlmnC
12	1	\N	\N	\N	iiVUoKpx
13	1	\N	\N	\N	gwYhnkHd
14	1	\N	\N	\N	CknRkpbr
15	1	\N	\N	\N	HqRkgMvU
16	1	\N	\N	\N	edIzHhiX
17	1	\N	\N	\N	klcRfeeU
18	1	\N	\N	\N	oDmfgnip
19	1	\N	\N	\N	DpVkFMzk
20	1	\N	\N	\N	DSUnqgmm
21	1	\N	\N	\N	pCgaSqXS
22	1	\N	\N	\N	NGJeAkMg
23	1	\N	\N	\N	sFECGfAg
24	1	\N	\N	\N	CQHjjfXy
25	1	\N	\N	\N	ZthlfRva
26	1	\N	\N	\N	HmQelePd
27	1	\N	\N	\N	llhgjLoL
28	1	\N	\N	\N	heslo
29	1	\N	\N	\N	heslo
30	1	\N	\N	\N	heslo
31	1	\N	\N	\N	heslo
32	1	\N	\N	\N	heslo
33	1	\N	\N	\N	heslo
34	1	\N	\N	\N	heslo
35	1	\N	\N	\N	heslo
36	1	\N	\N	\N	heslo
37	1	\N	\N	\N	heslo
38	1	\N	\N	\N	heslo
39	1	\N	\N	\N	heslo
40	1	\N	\N	\N	heslo
41	1	\N	\N	\N	heslo
42	1	\N	\N	\N	heslo
43	1	\N	\N	\N	heslo
44	1	\N	\N	\N	heslo
45	1	\N	\N	\N	heslo
46	1	\N	\N	\N	heslo
47	1	\N	\N	\N	heslo
48	1	\N	\N	\N	AxSOydOe
49	1	\N	\N	\N	agnbEgdF
50	1	\N	\N	\N	qajtjfTE
51	1	\N	\N	\N	RbbhRoRY
52	1	\N	\N	\N	IgPTcOjZ
53	1	\N	\N	\N	SdFdqLiT
54	1	\N	\N	\N	HbdKLagt
55	1	\N	\N	\N	jIOurhzB
56	1	\N	\N	\N	wmfKFDLi
57	1	\N	\N	\N	zbglzirw
58	1	\N	\N	\N	dOJkOTcq
\.


--
-- Data for Name: object_history; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY object_history (historyid, id, clid, upid, trdate, update, authinfopw) FROM stdin;
1	1	1	\N	\N	\N	RxuiIlbd
2	2	1	\N	\N	\N	ANuUSKZg
3	3	1	\N	\N	\N	NKekVvom
4	4	1	\N	\N	\N	AdfYsvDa
5	5	1	\N	\N	\N	KHmxphcy
6	6	1	\N	\N	\N	sMtuUAze
7	7	1	\N	\N	\N	PNhmLTYQ
8	8	1	\N	\N	\N	TrgdMfXu
9	9	1	\N	\N	\N	hfqiNFVJ
10	10	1	\N	\N	\N	KLachdTl
11	11	1	\N	\N	\N	pYmSlmnC
12	12	1	\N	\N	\N	iiVUoKpx
13	13	1	\N	\N	\N	gwYhnkHd
14	14	1	\N	\N	\N	CknRkpbr
15	15	1	\N	\N	\N	HqRkgMvU
16	16	1	\N	\N	\N	edIzHhiX
17	17	1	\N	\N	\N	klcRfeeU
18	18	1	\N	\N	\N	oDmfgnip
19	19	1	\N	\N	\N	DpVkFMzk
20	20	1	\N	\N	\N	DSUnqgmm
21	21	1	\N	\N	\N	pCgaSqXS
22	22	1	\N	\N	\N	NGJeAkMg
23	23	1	\N	\N	\N	sFECGfAg
24	24	1	\N	\N	\N	CQHjjfXy
25	25	1	\N	\N	\N	ZthlfRva
26	26	1	\N	\N	\N	HmQelePd
27	27	1	\N	\N	\N	llhgjLoL
28	28	1	\N	\N	\N	heslo
29	29	1	\N	\N	\N	heslo
30	30	1	\N	\N	\N	heslo
31	31	1	\N	\N	\N	heslo
32	32	1	\N	\N	\N	heslo
33	33	1	\N	\N	\N	heslo
34	34	1	\N	\N	\N	heslo
35	35	1	\N	\N	\N	heslo
36	36	1	\N	\N	\N	heslo
37	37	1	\N	\N	\N	heslo
38	38	1	\N	\N	\N	heslo
39	39	1	\N	\N	\N	heslo
40	40	1	\N	\N	\N	heslo
41	41	1	\N	\N	\N	heslo
42	42	1	\N	\N	\N	heslo
43	43	1	\N	\N	\N	heslo
44	44	1	\N	\N	\N	heslo
45	45	1	\N	\N	\N	heslo
46	46	1	\N	\N	\N	heslo
47	47	1	\N	\N	\N	heslo
48	48	1	\N	\N	\N	AxSOydOe
49	49	1	\N	\N	\N	agnbEgdF
50	50	1	\N	\N	\N	qajtjfTE
51	51	1	\N	\N	\N	RbbhRoRY
52	52	1	\N	\N	\N	IgPTcOjZ
53	53	1	\N	\N	\N	SdFdqLiT
54	54	1	\N	\N	\N	HbdKLagt
55	55	1	\N	\N	\N	jIOurhzB
56	56	1	\N	\N	\N	wmfKFDLi
57	57	1	\N	\N	\N	zbglzirw
58	58	1	\N	\N	\N	dOJkOTcq
\.


--
-- Data for Name: object_registry; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY object_registry (id, roid, type, name, crid, crdate, erdate, crhistoryid, historyid) FROM stdin;
1	C0000000001-CZ	1	CONTACT	1	2013-06-14 13:31:49.507845	\N	1	1
2	C0000000002-CZ	1	CIHAK	1	2013-06-14 13:31:49.804755	\N	2	2
3	C0000000003-CZ	1	PEPA	1	2013-06-14 13:31:50.0992	\N	3	3
4	C0000000004-CZ	1	ANNA	1	2013-06-14 13:31:50.396431	\N	4	4
5	C0000000005-CZ	1	FRANTA	1	2013-06-14 13:31:50.698085	\N	5	5
6	C0000000006-CZ	1	TESTER	1	2013-06-14 13:31:50.991574	\N	6	6
7	C0000000007-CZ	1	BOB	1	2013-06-14 13:31:51.297114	\N	7	7
8	N0000000008-CZ	2	NSSID01	1	2013-06-14 13:31:51.700438	\N	8	8
9	N0000000009-CZ	2	NSSID02	1	2013-06-14 13:31:51.989028	\N	9	9
10	N0000000010-CZ	2	NSSID03	1	2013-06-14 13:31:52.283892	\N	10	10
11	N0000000011-CZ	2	NSSID04	1	2013-06-14 13:31:52.570606	\N	11	11
12	N0000000012-CZ	2	NSSID05	1	2013-06-14 13:31:52.859109	\N	12	12
13	N0000000013-CZ	2	NSSID06	1	2013-06-14 13:31:53.147946	\N	13	13
14	N0000000014-CZ	2	NSSID07	1	2013-06-14 13:31:53.443404	\N	14	14
15	N0000000015-CZ	2	NSSID08	1	2013-06-14 13:31:53.737638	\N	15	15
16	N0000000016-CZ	2	NSSID09	1	2013-06-14 13:31:54.034925	\N	16	16
17	N0000000017-CZ	2	NSSID10	1	2013-06-14 13:31:54.324049	\N	17	17
18	K0000000018-CZ	4	KEYID01	1	2013-06-14 13:31:54.616493	\N	18	18
19	K0000000019-CZ	4	KEYID02	1	2013-06-14 13:31:54.888446	\N	19	19
20	K0000000020-CZ	4	KEYID03	1	2013-06-14 13:31:55.159982	\N	20	20
21	K0000000021-CZ	4	KEYID04	1	2013-06-14 13:31:55.438237	\N	21	21
22	K0000000022-CZ	4	KEYID05	1	2013-06-14 13:31:55.721359	\N	22	22
23	K0000000023-CZ	4	KEYID06	1	2013-06-14 13:31:56.001341	\N	23	23
24	K0000000024-CZ	4	KEYID07	1	2013-06-14 13:31:56.276888	\N	24	24
25	K0000000025-CZ	4	KEYID08	1	2013-06-14 13:31:56.558064	\N	25	25
26	K0000000026-CZ	4	KEYID09	1	2013-06-14 13:31:56.840544	\N	26	26
27	K0000000027-CZ	4	KEYID10	1	2013-06-14 13:31:57.124301	\N	27	27
28	D0000000028-CZ	3	nic01.cz	1	2013-06-14 13:31:57.394957	\N	28	28
29	D0000000029-CZ	3	nic02.cz	1	2013-06-14 13:31:57.701656	\N	29	29
30	D0000000030-CZ	3	nic03.cz	1	2013-06-14 13:31:58.0167	\N	30	30
31	D0000000031-CZ	3	nic04.cz	1	2013-06-14 13:31:58.33586	\N	31	31
32	D0000000032-CZ	3	nic05.cz	1	2013-06-14 13:31:58.648892	\N	32	32
33	D0000000033-CZ	3	nic06.cz	1	2013-06-14 13:31:58.954564	\N	33	33
34	D0000000034-CZ	3	nic07.cz	1	2013-06-14 13:31:59.265097	\N	34	34
35	D0000000035-CZ	3	nic08.cz	1	2013-06-14 13:31:59.574756	\N	35	35
36	D0000000036-CZ	3	nic09.cz	1	2013-06-14 13:31:59.885763	\N	36	36
37	D0000000037-CZ	3	nic10.cz	1	2013-06-14 13:32:00.190703	\N	37	37
38	D0000000038-CZ	3	ginger01.cz	1	2013-06-14 13:32:00.496137	\N	38	38
39	D0000000039-CZ	3	ginger02.cz	1	2013-06-14 13:32:00.795744	\N	39	39
40	D0000000040-CZ	3	ginger03.cz	1	2013-06-14 13:32:01.101111	\N	40	40
41	D0000000041-CZ	3	ginger04.cz	1	2013-06-14 13:32:01.413862	\N	41	41
42	D0000000042-CZ	3	ginger05.cz	1	2013-06-14 13:32:01.723489	\N	42	42
43	D0000000043-CZ	3	ginger06.cz	1	2013-06-14 13:32:02.043755	\N	43	43
44	D0000000044-CZ	3	ginger07.cz	1	2013-06-14 13:32:02.3474	\N	44	44
45	D0000000045-CZ	3	ginger08.cz	1	2013-06-14 13:32:02.65207	\N	45	45
46	D0000000046-CZ	3	ginger09.cz	1	2013-06-14 13:32:02.954036	\N	46	46
47	D0000000047-CZ	3	ginger10.cz	1	2013-06-14 13:32:03.249372	\N	47	47
48	D0000000048-CZ	3	1.1.1.8.4.5.2.2.2.0.2.4.e164.arpa	1	2013-06-14 13:32:03.556195	\N	48	48
49	D0000000049-CZ	3	2.1.1.8.4.5.2.2.2.0.2.4.e164.arpa	1	2013-06-14 13:32:03.871668	\N	49	49
50	D0000000050-CZ	3	3.1.1.8.4.5.2.2.2.0.2.4.e164.arpa	1	2013-06-14 13:32:04.191737	\N	50	50
51	D0000000051-CZ	3	4.1.1.8.4.5.2.2.2.0.2.4.e164.arpa	1	2013-06-14 13:32:04.509135	\N	51	51
52	D0000000052-CZ	3	5.1.1.8.4.5.2.2.2.0.2.4.e164.arpa	1	2013-06-14 13:32:04.825451	\N	52	52
53	D0000000053-CZ	3	6.1.1.8.4.5.2.2.2.0.2.4.e164.arpa	1	2013-06-14 13:32:05.143058	\N	53	53
54	D0000000054-CZ	3	7.1.1.8.4.5.2.2.2.0.2.4.e164.arpa	1	2013-06-14 13:32:05.464421	\N	54	54
55	D0000000055-CZ	3	8.1.1.8.4.5.2.2.2.0.2.4.e164.arpa	1	2013-06-14 13:32:05.773889	\N	55	55
56	D0000000056-CZ	3	9.1.1.8.4.5.2.2.2.0.2.4.e164.arpa	1	2013-06-14 13:32:06.084387	\N	56	56
57	D0000000057-CZ	3	0.2.1.8.4.5.2.2.2.0.2.4.e164.arpa	1	2013-06-14 13:32:06.391219	\N	57	57
58	D0000000058-CZ	3	1.2.1.8.4.5.2.2.2.0.2.4.e164.arpa	1	2013-06-14 13:32:06.702794	\N	58	58
\.


--
-- Data for Name: object_state; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY object_state (id, object_id, state_id, valid_from, valid_to, ohid_from, ohid_to) FROM stdin;
1	6	23	2013-06-14 13:31:51.527904	\N	6	\N
2	6	16	2013-06-14 13:31:51.700438	\N	6	\N
3	4	16	2013-06-14 13:31:51.700438	\N	4	\N
43	8	16	2013-06-14 13:31:57.394957	\N	8	\N
44	18	16	2013-06-14 13:31:57.394957	\N	18	\N
136	7	16	2013-06-14 13:32:03.556195	\N	7	\N
\.


--
-- Data for Name: object_state_request; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY object_state_request (id, object_id, state_id, valid_from, valid_to, crdate, canceled) FROM stdin;
1	6	23	2013-06-14 13:31:51.524688	\N	2013-06-14 13:31:51.524688	\N
\.


--
-- Data for Name: object_state_request_lock; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY object_state_request_lock (id, state_id, object_id) FROM stdin;
1	23	6
\.


--
-- Data for Name: poll_credit; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY poll_credit (msgid, zone, credlimit, credit) FROM stdin;
\.


--
-- Data for Name: poll_credit_zone_limit; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY poll_credit_zone_limit (zone, credlimit) FROM stdin;
\.


--
-- Data for Name: poll_eppaction; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY poll_eppaction (msgid, objid) FROM stdin;
\.


--
-- Data for Name: poll_request_fee; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY poll_request_fee (msgid, period_from, period_to, total_free_count, used_count, price) FROM stdin;
\.


--
-- Data for Name: poll_statechange; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY poll_statechange (msgid, stateid) FROM stdin;
\.


--
-- Data for Name: poll_techcheck; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY poll_techcheck (msgid, cnid) FROM stdin;
\.


--
-- Data for Name: price_list; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY price_list (id, zone_id, operation_id, valid_from, valid_to, price, quantity, enable_postpaid_operation) FROM stdin;
1	2	1	2009-12-31 23:00:00	\N	0.00	1	f
2	2	1	2007-09-29 19:15:56.186031	2009-12-31 23:00:00	0.00	1	f
3	2	2	2009-12-31 23:00:00	2011-01-31 23:00:00	155.00	1	f
4	2	2	2011-01-31 23:00:00	\N	140.00	1	f
5	2	2	2007-09-29 19:15:56.159594	2009-12-31 23:00:00	190.00	1	f
6	1	1	2007-01-22 13:00:00	\N	0.00	1	f
7	1	2	2007-01-22 13:00:00	\N	1.00	1	f
8	2	3	2011-05-31 22:00:00	\N	0.10	1	t
\.


--
-- Data for Name: price_vat; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY price_vat (id, valid_to, koef, vat) FROM stdin;
1	2004-04-30 22:00:00	0.1803	22
2	2009-12-31 23:00:00	0.1597	19
3	\N	0.1667	20
\.


--
-- Data for Name: public_request; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY public_request (id, request_type, create_time, status, resolve_time, reason, email_to_answer, answer_email_id, registrar_id, create_request_id, resolve_request_id) FROM stdin;
\.


--
-- Data for Name: public_request_auth; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY public_request_auth (id, identification, password) FROM stdin;
\.


--
-- Data for Name: public_request_lock; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY public_request_lock (id, request_type, object_id) FROM stdin;
\.


--
-- Data for Name: public_request_messages_map; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY public_request_messages_map (id, public_request_id, message_archive_id, mail_archive_id) FROM stdin;
\.


--
-- Data for Name: public_request_objects_map; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY public_request_objects_map (request_id, object_id) FROM stdin;
\.


--
-- Data for Name: public_request_state_request_map; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY public_request_state_request_map (state_request_id, block_request_id, unblock_request_id) FROM stdin;
\.


--
-- Data for Name: registrar; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY registrar (id, ico, dic, varsymb, vat, handle, name, organization, street1, street2, street3, city, stateorprovince, postalcode, country, telephone, fax, email, url, system, regex) FROM stdin;
1	\N	\N	12345     	t	REG-FRED_A	Company A l.t.d	Testing registrar A	\N	\N	\N	\N	\N	\N	CZ	\N	\N	kuk@nic.cz	www.nic.cz	f	\N
2	\N	\N	12346     	t	REG-FRED_B	Company B l.t.d.	Testing registrar B	\N	\N	\N	\N	\N	\N	CZ	\N	\N	kuk@nic.cz	www.nic.cz	f	\N
3	456753212	6208254562	TESt      	t	REG-FRED_C	Pepa Karel	abc s.r.o.	Adr 1	Adr 2	Adr 3	Prague	state	120 00	CZ	4561230	789123456	kuk@nic.cz	www.kuk.cz	t	\N
4	\N	\N	12347     	t	REG-FRED_NOCRED	Company NOCRED l.t.d.	Testing registrar NOCRED	\N	\N	\N	\N	\N	\N	CZ	\N	\N	kuk@nic.cz	www.nic.cz	f	\N
5	\N	\N	\N	t	REG-MOJEID	Company B l.t.d.	MojeID registrar	\N	\N	\N	\N	\N	\N	CZ	\N	\N	kuk@nic.cz	www.nic.cz	f	\N
\.


--
-- Data for Name: registrar_certification; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY registrar_certification (id, registrar_id, valid_from, valid_until, classification, eval_file_id) FROM stdin;
1	1	2013-06-14	2015-08-26	2	1
\.


--
-- Data for Name: registrar_credit; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY registrar_credit (id, credit, registrar_id, zone_id) FROM stdin;
7	0.00	4	1
8	0.00	4	2
5	467676.29	3	1
6	195459.68	3	2
9	0.00	5	2
3	511100.39	2	1
4	290498.38	2	2
2	372520.60	1	2
1	103698.18	1	1
\.


--
-- Data for Name: registrar_credit_transaction; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY registrar_credit_transaction (id, balance_change, registrar_credit_id) FROM stdin;
1	102875.88	1
2	510267.09	3
3	467676.29	5
4	380087.30	2
5	287998.48	4
6	195459.68	6
7	833.30	2
8	833.30	4
9	833.30	1
10	833.30	3
11	833.30	4
12	833.30	4
13	0.00	2
14	-420.00	2
15	0.00	2
16	-420.00	2
17	0.00	2
18	-420.00	2
19	0.00	2
20	-420.00	2
21	0.00	2
22	-420.00	2
23	0.00	2
24	-420.00	2
25	0.00	2
26	-420.00	2
27	0.00	2
28	-420.00	2
29	0.00	2
30	-420.00	2
31	0.00	2
32	-420.00	2
33	0.00	2
34	-420.00	2
35	0.00	2
36	-420.00	2
37	0.00	2
38	-420.00	2
39	0.00	2
40	-420.00	2
41	0.00	2
42	-420.00	2
43	0.00	2
44	-420.00	2
45	0.00	2
46	-420.00	2
47	0.00	2
48	-420.00	2
49	0.00	2
50	-420.00	2
51	0.00	2
52	-420.00	2
53	0.00	1
54	-1.00	1
55	0.00	1
56	-1.00	1
57	0.00	1
58	-1.00	1
59	0.00	1
60	-1.00	1
61	0.00	1
62	-1.00	1
63	0.00	1
64	-1.00	1
65	0.00	1
66	-1.00	1
67	0.00	1
68	-1.00	1
69	0.00	1
70	-1.00	1
71	0.00	1
72	-1.00	1
73	0.00	1
74	-1.00	1
\.


--
-- Data for Name: registrar_disconnect; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY registrar_disconnect (id, registrarid, blocked_from, blocked_to, unblock_request_id) FROM stdin;
\.


--
-- Data for Name: registrar_group; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY registrar_group (id, short_name, cancelled) FROM stdin;
1	certified	\N
2	uncertified	\N
3	dnssec	\N
4	ipv6	\N
5	mojeid	\N
\.


--
-- Data for Name: registrar_group_map; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY registrar_group_map (id, registrar_id, registrar_group_id, member_from, member_until) FROM stdin;
1	1	1	2013-06-14	\N
2	2	1	2013-06-14	\N
3	3	2	2013-06-14	\N
4	1	3	2013-06-14	\N
5	1	5	2013-06-14	\N
6	2	4	2013-06-14	\N
\.


--
-- Data for Name: registraracl; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY registraracl (id, registrarid, cert, password) FROM stdin;
1	1	39:D1:0C:CA:05:3A:CC:C0:0B:EC:6F:3F:81:0D:C7:9E	passwd
2	2	39:D1:0C:CA:05:3A:CC:C0:0B:EC:6F:3F:81:0D:C7:9E	passwd
3	3	60:7E:DF:39:62:C3:9D:3C:EB:5A:87:80:C1:73:4F:99	passwd
4	3	39:D1:0C:CA:05:3A:CC:C0:0B:EC:6F:3F:81:0D:C7:9E	passwd
5	4	39:D1:0C:CA:05:3A:CC:C0:0B:EC:6F:3F:81:0D:C7:9E	passwd
6	5	39:D1:0C:CA:05:3A:CC:C0:0B:EC:6F:3F:81:0D:C7:9E	passwd
\.


--
-- Data for Name: registrarinvoice; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY registrarinvoice (id, registrarid, zone, fromdate, todate) FROM stdin;
1	1	1	2007-01-01	\N
2	1	2	2007-01-01	\N
3	2	1	2007-01-01	\N
4	2	2	2007-01-01	\N
5	3	1	2007-01-01	\N
6	3	2	2007-01-01	\N
7	4	1	2007-01-01	\N
8	4	2	2007-01-01	\N
9	5	2	2007-01-01	\N
\.


--
-- Data for Name: reminder_contact_message_map; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY reminder_contact_message_map (reminder_date, contact_id, message_id) FROM stdin;
\.


--
-- Data for Name: reminder_registrar_parameter; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY reminder_registrar_parameter (registrar_id, template_memo, reply_to) FROM stdin;
\.


--
-- Data for Name: request; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY request (id, time_begin, time_end, source_ip, service_id, request_type_id, session_id, user_name, is_monitoring, result_code_id, user_id) FROM stdin;
\.


--
-- Data for Name: request_data; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY request_data (id, request_time_begin, request_service_id, request_monitoring, request_id, content, is_response) FROM stdin;
\.


--
-- Data for Name: request_data_epp_13_06; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY request_data_epp_13_06 (id, request_time_begin, request_service_id, request_monitoring, request_id, content, is_response) FROM stdin;
1	2013-06-14 13:31:49.377405	3	f	1	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>acef001#13-06-14at15:31:49</clTRID></command></epp>\n	f
2	2013-06-14 13:31:49.377405	3	f	1	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>acef001#13-06-14at15:31:49</clTRID><svTRID>ReqID-0000000001</svTRID></trID></response></epp>\n	t
3	2013-06-14 13:31:49.459803	3	f	2	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><contact:create xmlns:contact="http://www.nic.cz/xml/epp/contact-1.6" xsi:schemaLocation="http://www.nic.cz/xml/epp/contact-1.6 contact-1.6.xsd"><contact:id>CONTACT</contact:id><contact:postalInfo><contact:name>Freddy First</contact:name><contact:org>Company Fred s.p.z.o.</contact:org><contact:addr><contact:street>Wallstreet 16/3</contact:street><contact:city>New York</contact:city><contact:pc>12601</contact:pc><contact:cc>CZ</contact:cc></contact:addr></contact:postalInfo><contact:voice>+420.726123455</contact:voice><contact:fax>+420.726123456</contact:fax><contact:email>freddy.first@nic.czcz</contact:email><contact:disclose flag="0"><contact:fax/><contact:vat/><contact:ident/><contact:notifyEmail/></contact:disclose><contact:vat>CZ1234567889</contact:vat><contact:ident type="op">84956250</contact:ident><contact:notifyEmail>freddy+notify@nic.czcz</contact:notifyEmail></contact:create></create><clTRID>acef002#13-06-14at15:31:49</clTRID></command></epp>\n	f
4	2013-06-14 13:31:49.459803	3	f	2	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><contact:creData xmlns:contact="http://www.nic.cz/xml/epp/contact-1.6" xsi:schemaLocation="http://www.nic.cz/xml/epp/contact-1.6 contact-1.6.1.xsd"><contact:id>CONTACT</contact:id><contact:crDate>2013-06-14T15:31:49+02:00</contact:crDate></contact:creData></resData><trID><clTRID>acef002#13-06-14at15:31:49</clTRID><svTRID>ReqID-0000000002</svTRID></trID></response></epp>\n	t
5	2013-06-14 13:31:49.578717	3	f	3	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>acef003#13-06-14at15:31:49</clTRID></command></epp>\n	f
6	2013-06-14 13:31:49.578717	3	f	3	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>acef003#13-06-14at15:31:49</clTRID><svTRID>ReqID-0000000003</svTRID></trID></response></epp>\n	t
7	2013-06-14 13:31:49.696274	3	f	4	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>tett001#13-06-14at15:31:49</clTRID></command></epp>\n	f
8	2013-06-14 13:31:49.696274	3	f	4	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>tett001#13-06-14at15:31:49</clTRID><svTRID>ReqID-0000000004</svTRID></trID></response></epp>\n	t
9	2013-06-14 13:31:49.756596	3	f	5	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><contact:create xmlns:contact="http://www.nic.cz/xml/epp/contact-1.6" xsi:schemaLocation="http://www.nic.cz/xml/epp/contact-1.6 contact-1.6.xsd"><contact:id>CIHAK</contact:id><contact:postalInfo><contact:name>Řehoř Čihák</contact:name><contact:org>Firma Čihák a spol.</contact:org><contact:addr><contact:street>Přípotoční 16/3</contact:street><contact:city>Říčany u Prahy</contact:city><contact:pc>12601</contact:pc><contact:cc>CZ</contact:cc></contact:addr></contact:postalInfo><contact:voice>+420.726123456</contact:voice><contact:fax>+420.726123455</contact:fax><contact:email>rehor.cihak@nic.czcz</contact:email><contact:disclose flag="0"><contact:fax/><contact:vat/><contact:ident/><contact:notifyEmail/></contact:disclose><contact:vat>CZ1234567890</contact:vat><contact:ident type="op">84956251</contact:ident><contact:notifyEmail>cihak+notify@nic.czcz</contact:notifyEmail></contact:create></create><clTRID>tett002#13-06-14at15:31:49</clTRID></command></epp>\n	f
10	2013-06-14 13:31:49.756596	3	f	5	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><contact:creData xmlns:contact="http://www.nic.cz/xml/epp/contact-1.6" xsi:schemaLocation="http://www.nic.cz/xml/epp/contact-1.6 contact-1.6.1.xsd"><contact:id>CIHAK</contact:id><contact:crDate>2013-06-14T15:31:49+02:00</contact:crDate></contact:creData></resData><trID><clTRID>tett002#13-06-14at15:31:49</clTRID><svTRID>ReqID-0000000005</svTRID></trID></response></epp>\n	t
11	2013-06-14 13:31:49.867874	3	f	6	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>tett003#13-06-14at15:31:49</clTRID></command></epp>\n	f
12	2013-06-14 13:31:49.867874	3	f	6	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>tett003#13-06-14at15:31:49</clTRID><svTRID>ReqID-0000000006</svTRID></trID></response></epp>\n	t
13	2013-06-14 13:31:49.990702	3	f	7	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>kvuh001#13-06-14at15:31:49</clTRID></command></epp>\n	f
14	2013-06-14 13:31:49.990702	3	f	7	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>kvuh001#13-06-14at15:31:49</clTRID><svTRID>ReqID-0000000007</svTRID></trID></response></epp>\n	t
15	2013-06-14 13:31:50.051062	3	f	8	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><contact:create xmlns:contact="http://www.nic.cz/xml/epp/contact-1.6" xsi:schemaLocation="http://www.nic.cz/xml/epp/contact-1.6 contact-1.6.xsd"><contact:id>PEPA</contact:id><contact:postalInfo><contact:name>Pepa Zdepa</contact:name><contact:org>Firma Pepa s.r.o.</contact:org><contact:addr><contact:street>U práce 453</contact:street><contact:city>Praha</contact:city><contact:pc>12300</contact:pc><contact:cc>CZ</contact:cc></contact:addr></contact:postalInfo><contact:voice>+420.726123457</contact:voice><contact:fax>+420.726123454</contact:fax><contact:email>pepa.zdepa@nic.czcz</contact:email><contact:disclose flag="0"><contact:fax/><contact:vat/><contact:ident/><contact:notifyEmail/></contact:disclose><contact:vat>CZ1234567891</contact:vat><contact:ident type="op">84956252</contact:ident><contact:notifyEmail>pepa+notify@nic.czcz</contact:notifyEmail></contact:create></create><clTRID>kvuh002#13-06-14at15:31:50</clTRID></command></epp>\n	f
16	2013-06-14 13:31:50.051062	3	f	8	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><contact:creData xmlns:contact="http://www.nic.cz/xml/epp/contact-1.6" xsi:schemaLocation="http://www.nic.cz/xml/epp/contact-1.6 contact-1.6.1.xsd"><contact:id>PEPA</contact:id><contact:crDate>2013-06-14T15:31:50+02:00</contact:crDate></contact:creData></resData><trID><clTRID>kvuh002#13-06-14at15:31:50</clTRID><svTRID>ReqID-0000000008</svTRID></trID></response></epp>\n	t
17	2013-06-14 13:31:50.163623	3	f	9	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>kvuh003#13-06-14at15:31:50</clTRID></command></epp>\n	f
18	2013-06-14 13:31:50.163623	3	f	9	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>kvuh003#13-06-14at15:31:50</clTRID><svTRID>ReqID-0000000009</svTRID></trID></response></epp>\n	t
19	2013-06-14 13:31:50.28923	3	f	10	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>uswf001#13-06-14at15:31:50</clTRID></command></epp>\n	f
20	2013-06-14 13:31:50.28923	3	f	10	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>uswf001#13-06-14at15:31:50</clTRID><svTRID>ReqID-0000000010</svTRID></trID></response></epp>\n	t
21	2013-06-14 13:31:50.349693	3	f	11	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><contact:create xmlns:contact="http://www.nic.cz/xml/epp/contact-1.6" xsi:schemaLocation="http://www.nic.cz/xml/epp/contact-1.6 contact-1.6.xsd"><contact:id>ANNA</contact:id><contact:postalInfo><contact:name>Anna Procházková</contact:name><contact:addr><contact:street>Za želvami 32</contact:street><contact:city>Louňovice</contact:city><contact:pc>12808</contact:pc><contact:cc>CZ</contact:cc></contact:addr></contact:postalInfo><contact:voice>+420.726123458</contact:voice><contact:fax>+420.726123453</contact:fax><contact:email>anna.prochazkova@nic.czcz</contact:email><contact:disclose flag="0"><contact:fax/><contact:vat/><contact:ident/><contact:notifyEmail/></contact:disclose><contact:vat>CZ1234567892</contact:vat><contact:ident type="op">84956253</contact:ident><contact:notifyEmail>anna+notify@nic.czcz</contact:notifyEmail></contact:create></create><clTRID>uswf002#13-06-14at15:31:50</clTRID></command></epp>\n	f
22	2013-06-14 13:31:50.349693	3	f	11	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><contact:creData xmlns:contact="http://www.nic.cz/xml/epp/contact-1.6" xsi:schemaLocation="http://www.nic.cz/xml/epp/contact-1.6 contact-1.6.1.xsd"><contact:id>ANNA</contact:id><contact:crDate>2013-06-14T15:31:50+02:00</contact:crDate></contact:creData></resData><trID><clTRID>uswf002#13-06-14at15:31:50</clTRID><svTRID>ReqID-0000000011</svTRID></trID></response></epp>\n	t
23	2013-06-14 13:31:50.459946	3	f	12	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>uswf003#13-06-14at15:31:50</clTRID></command></epp>\n	f
24	2013-06-14 13:31:50.459946	3	f	12	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>uswf003#13-06-14at15:31:50</clTRID><svTRID>ReqID-0000000012</svTRID></trID></response></epp>\n	t
25	2013-06-14 13:31:50.589583	3	f	13	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>zigy001#13-06-14at15:31:50</clTRID></command></epp>\n	f
26	2013-06-14 13:31:50.589583	3	f	13	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>zigy001#13-06-14at15:31:50</clTRID><svTRID>ReqID-0000000013</svTRID></trID></response></epp>\n	t
27	2013-06-14 13:31:50.651337	3	f	14	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><contact:create xmlns:contact="http://www.nic.cz/xml/epp/contact-1.6" xsi:schemaLocation="http://www.nic.cz/xml/epp/contact-1.6 contact-1.6.xsd"><contact:id>FRANTA</contact:id><contact:postalInfo><contact:name>František Kocourek</contact:name><contact:addr><contact:street>Žabovřesky 4567</contact:street><contact:city>Brno</contact:city><contact:pc>18000</contact:pc><contact:cc>CZ</contact:cc></contact:addr></contact:postalInfo><contact:voice>+420.726123459</contact:voice><contact:fax>+420.726123452</contact:fax><contact:email>franta.kocourek@nic.czcz</contact:email><contact:disclose flag="0"><contact:fax/><contact:vat/><contact:ident/><contact:notifyEmail/></contact:disclose><contact:vat>CZ1234567893</contact:vat><contact:ident type="op">84956254</contact:ident><contact:notifyEmail>franta+notify@nic.czcz</contact:notifyEmail></contact:create></create><clTRID>zigy002#13-06-14at15:31:50</clTRID></command></epp>\n	f
28	2013-06-14 13:31:50.651337	3	f	14	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><contact:creData xmlns:contact="http://www.nic.cz/xml/epp/contact-1.6" xsi:schemaLocation="http://www.nic.cz/xml/epp/contact-1.6 contact-1.6.1.xsd"><contact:id>FRANTA</contact:id><contact:crDate>2013-06-14T15:31:50+02:00</contact:crDate></contact:creData></resData><trID><clTRID>zigy002#13-06-14at15:31:50</clTRID><svTRID>ReqID-0000000014</svTRID></trID></response></epp>\n	t
29	2013-06-14 13:31:50.762072	3	f	15	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>zigy003#13-06-14at15:31:50</clTRID></command></epp>\n	f
30	2013-06-14 13:31:50.762072	3	f	15	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>zigy003#13-06-14at15:31:50</clTRID><svTRID>ReqID-0000000015</svTRID></trID></response></epp>\n	t
31	2013-06-14 13:31:50.884535	3	f	16	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>gtql001#13-06-14at15:31:50</clTRID></command></epp>\n	f
32	2013-06-14 13:31:50.884535	3	f	16	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>gtql001#13-06-14at15:31:50</clTRID><svTRID>ReqID-0000000016</svTRID></trID></response></epp>\n	t
33	2013-06-14 13:31:50.944806	3	f	17	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><contact:create xmlns:contact="http://www.nic.cz/xml/epp/contact-1.6" xsi:schemaLocation="http://www.nic.cz/xml/epp/contact-1.6 contact-1.6.xsd"><contact:id>TESTER</contact:id><contact:postalInfo><contact:name>Tomáš Tester</contact:name><contact:addr><contact:street>Testovní 35</contact:street><contact:city>Plzeň</contact:city><contact:pc>16200</contact:pc><contact:cc>CZ</contact:cc></contact:addr></contact:postalInfo><contact:voice>+420.726123460</contact:voice><contact:fax>+420.726123451</contact:fax><contact:email>tomas.tester@nic.czcz</contact:email><contact:disclose flag="0"><contact:fax/><contact:vat/><contact:ident/><contact:notifyEmail/></contact:disclose><contact:vat>CZ1234567894</contact:vat><contact:ident type="op">84956253</contact:ident><contact:notifyEmail>tester+notify@nic.czcz</contact:notifyEmail></contact:create></create><clTRID>gtql002#13-06-14at15:31:50</clTRID></command></epp>\n	f
34	2013-06-14 13:31:50.944806	3	f	17	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><contact:creData xmlns:contact="http://www.nic.cz/xml/epp/contact-1.6" xsi:schemaLocation="http://www.nic.cz/xml/epp/contact-1.6 contact-1.6.1.xsd"><contact:id>TESTER</contact:id><contact:crDate>2013-06-14T15:31:50+02:00</contact:crDate></contact:creData></resData><trID><clTRID>gtql002#13-06-14at15:31:50</clTRID><svTRID>ReqID-0000000017</svTRID></trID></response></epp>\n	t
35	2013-06-14 13:31:51.059879	3	f	18	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>gtql003#13-06-14at15:31:51</clTRID></command></epp>\n	f
36	2013-06-14 13:31:51.059879	3	f	18	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>gtql003#13-06-14at15:31:51</clTRID><svTRID>ReqID-0000000018</svTRID></trID></response></epp>\n	t
37	2013-06-14 13:31:51.189496	3	f	19	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>szql001#13-06-14at15:31:51</clTRID></command></epp>\n	f
38	2013-06-14 13:31:51.189496	3	f	19	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>szql001#13-06-14at15:31:51</clTRID><svTRID>ReqID-0000000019</svTRID></trID></response></epp>\n	t
39	2013-06-14 13:31:51.250398	3	f	20	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><contact:create xmlns:contact="http://www.nic.cz/xml/epp/contact-1.6" xsi:schemaLocation="http://www.nic.cz/xml/epp/contact-1.6 contact-1.6.xsd"><contact:id>BOB</contact:id><contact:postalInfo><contact:name>Bobeš Šuflík</contact:name><contact:addr><contact:street>Báňská 35</contact:street><contact:city>Domažlice</contact:city><contact:pc>18200</contact:pc><contact:cc>CZ</contact:cc></contact:addr></contact:postalInfo><contact:voice>+420.726123461</contact:voice><contact:fax>+420.726123450</contact:fax><contact:email>bobes.suflik@nic.czcz</contact:email><contact:disclose flag="0"><contact:fax/><contact:vat/><contact:ident/><contact:notifyEmail/></contact:disclose><contact:vat>CZ1234567895</contact:vat><contact:ident type="op">84956252</contact:ident><contact:notifyEmail>bob+notify@nic.czcz</contact:notifyEmail></contact:create></create><clTRID>szql002#13-06-14at15:31:51</clTRID></command></epp>\n	f
40	2013-06-14 13:31:51.250398	3	f	20	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><contact:creData xmlns:contact="http://www.nic.cz/xml/epp/contact-1.6" xsi:schemaLocation="http://www.nic.cz/xml/epp/contact-1.6 contact-1.6.1.xsd"><contact:id>BOB</contact:id><contact:crDate>2013-06-14T15:31:51+02:00</contact:crDate></contact:creData></resData><trID><clTRID>szql002#13-06-14at15:31:51</clTRID><svTRID>ReqID-0000000020</svTRID></trID></response></epp>\n	t
41	2013-06-14 13:31:51.361512	3	f	21	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>szql003#13-06-14at15:31:51</clTRID></command></epp>\n	f
42	2013-06-14 13:31:51.361512	3	f	21	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>szql003#13-06-14at15:31:51</clTRID><svTRID>ReqID-0000000021</svTRID></trID></response></epp>\n	t
43	2013-06-14 13:31:51.613755	3	f	22	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>iyyh001#13-06-14at15:31:51</clTRID></command></epp>\n	f
44	2013-06-14 13:31:51.613755	3	f	22	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>iyyh001#13-06-14at15:31:51</clTRID><svTRID>ReqID-0000000022</svTRID></trID></response></epp>\n	t
45	2013-06-14 13:31:51.672815	3	f	23	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><nsset:create xmlns:nsset="http://www.nic.cz/xml/epp/nsset-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/nsset-1.2 nsset-1.2.xsd"><nsset:id>nssid01</nsset:id><nsset:ns><nsset:name>ns1.domain.cz</nsset:name><nsset:addr>217.31.207.130</nsset:addr><nsset:addr>217.31.207.129</nsset:addr></nsset:ns><nsset:ns><nsset:name>ns2.domain.cz</nsset:name><nsset:addr>217.31.206.130</nsset:addr><nsset:addr>217.31.206.129</nsset:addr></nsset:ns><nsset:tech>TESTER</nsset:tech><nsset:tech>anna</nsset:tech></nsset:create></create><clTRID>iyyh002#13-06-14at15:31:51</clTRID></command></epp>\n	f
46	2013-06-14 13:31:51.672815	3	f	23	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><nsset:creData xmlns:nsset="http://www.nic.cz/xml/epp/nsset-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/nsset-1.2 nsset-1.2.1.xsd"><nsset:id>nssid01</nsset:id><nsset:crDate>2013-06-14T15:31:51+02:00</nsset:crDate></nsset:creData></resData><trID><clTRID>iyyh002#13-06-14at15:31:51</clTRID><svTRID>ReqID-0000000023</svTRID></trID></response></epp>\n	t
47	2013-06-14 13:31:51.785499	3	f	24	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>iyyh003#13-06-14at15:31:51</clTRID></command></epp>\n	f
48	2013-06-14 13:31:51.785499	3	f	24	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>iyyh003#13-06-14at15:31:51</clTRID><svTRID>ReqID-0000000024</svTRID></trID></response></epp>\n	t
49	2013-06-14 13:31:51.902495	3	f	25	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>ovie001#13-06-14at15:31:51</clTRID></command></epp>\n	f
50	2013-06-14 13:31:51.902495	3	f	25	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>ovie001#13-06-14at15:31:51</clTRID><svTRID>ReqID-0000000025</svTRID></trID></response></epp>\n	t
51	2013-06-14 13:31:51.961345	3	f	26	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><nsset:create xmlns:nsset="http://www.nic.cz/xml/epp/nsset-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/nsset-1.2 nsset-1.2.xsd"><nsset:id>nssid02</nsset:id><nsset:ns><nsset:name>ns1.domain.cz</nsset:name><nsset:addr>217.31.207.130</nsset:addr><nsset:addr>217.31.207.129</nsset:addr></nsset:ns><nsset:ns><nsset:name>ns2.domain.cz</nsset:name><nsset:addr>217.31.206.130</nsset:addr><nsset:addr>217.31.206.129</nsset:addr></nsset:ns><nsset:tech>TESTER</nsset:tech><nsset:tech>anna</nsset:tech></nsset:create></create><clTRID>ovie002#13-06-14at15:31:51</clTRID></command></epp>\n	f
52	2013-06-14 13:31:51.961345	3	f	26	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><nsset:creData xmlns:nsset="http://www.nic.cz/xml/epp/nsset-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/nsset-1.2 nsset-1.2.1.xsd"><nsset:id>nssid02</nsset:id><nsset:crDate>2013-06-14T15:31:51+02:00</nsset:crDate></nsset:creData></resData><trID><clTRID>ovie002#13-06-14at15:31:51</clTRID><svTRID>ReqID-0000000026</svTRID></trID></response></epp>\n	t
53	2013-06-14 13:31:52.070041	3	f	27	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>ovie003#13-06-14at15:31:52</clTRID></command></epp>\n	f
54	2013-06-14 13:31:52.070041	3	f	27	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>ovie003#13-06-14at15:31:52</clTRID><svTRID>ReqID-0000000027</svTRID></trID></response></epp>\n	t
55	2013-06-14 13:31:52.19672	3	f	28	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>vsvn001#13-06-14at15:31:52</clTRID></command></epp>\n	f
56	2013-06-14 13:31:52.19672	3	f	28	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>vsvn001#13-06-14at15:31:52</clTRID><svTRID>ReqID-0000000028</svTRID></trID></response></epp>\n	t
57	2013-06-14 13:31:52.25608	3	f	29	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><nsset:create xmlns:nsset="http://www.nic.cz/xml/epp/nsset-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/nsset-1.2 nsset-1.2.xsd"><nsset:id>nssid03</nsset:id><nsset:ns><nsset:name>ns1.domain.cz</nsset:name><nsset:addr>217.31.207.130</nsset:addr><nsset:addr>217.31.207.129</nsset:addr></nsset:ns><nsset:ns><nsset:name>ns2.domain.cz</nsset:name><nsset:addr>217.31.206.130</nsset:addr><nsset:addr>217.31.206.129</nsset:addr></nsset:ns><nsset:tech>TESTER</nsset:tech><nsset:tech>anna</nsset:tech></nsset:create></create><clTRID>vsvn002#13-06-14at15:31:52</clTRID></command></epp>\n	f
58	2013-06-14 13:31:52.25608	3	f	29	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><nsset:creData xmlns:nsset="http://www.nic.cz/xml/epp/nsset-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/nsset-1.2 nsset-1.2.1.xsd"><nsset:id>nssid03</nsset:id><nsset:crDate>2013-06-14T15:31:52+02:00</nsset:crDate></nsset:creData></resData><trID><clTRID>vsvn002#13-06-14at15:31:52</clTRID><svTRID>ReqID-0000000029</svTRID></trID></response></epp>\n	t
59	2013-06-14 13:31:52.365794	3	f	30	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>vsvn003#13-06-14at15:31:52</clTRID></command></epp>\n	f
60	2013-06-14 13:31:52.365794	3	f	30	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>vsvn003#13-06-14at15:31:52</clTRID><svTRID>ReqID-0000000030</svTRID></trID></response></epp>\n	t
61	2013-06-14 13:31:52.487891	3	f	31	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>jdtt001#13-06-14at15:31:52</clTRID></command></epp>\n	f
62	2013-06-14 13:31:52.487891	3	f	31	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>jdtt001#13-06-14at15:31:52</clTRID><svTRID>ReqID-0000000031</svTRID></trID></response></epp>\n	t
63	2013-06-14 13:31:52.547287	3	f	32	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><nsset:create xmlns:nsset="http://www.nic.cz/xml/epp/nsset-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/nsset-1.2 nsset-1.2.xsd"><nsset:id>nssid04</nsset:id><nsset:ns><nsset:name>ns1.domain.cz</nsset:name><nsset:addr>217.31.207.130</nsset:addr><nsset:addr>217.31.207.129</nsset:addr></nsset:ns><nsset:ns><nsset:name>ns2.domain.cz</nsset:name><nsset:addr>217.31.206.130</nsset:addr><nsset:addr>217.31.206.129</nsset:addr></nsset:ns><nsset:tech>TESTER</nsset:tech><nsset:tech>anna</nsset:tech></nsset:create></create><clTRID>jdtt002#13-06-14at15:31:52</clTRID></command></epp>\n	f
64	2013-06-14 13:31:52.547287	3	f	32	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><nsset:creData xmlns:nsset="http://www.nic.cz/xml/epp/nsset-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/nsset-1.2 nsset-1.2.1.xsd"><nsset:id>nssid04</nsset:id><nsset:crDate>2013-06-14T15:31:52+02:00</nsset:crDate></nsset:creData></resData><trID><clTRID>jdtt002#13-06-14at15:31:52</clTRID><svTRID>ReqID-0000000032</svTRID></trID></response></epp>\n	t
65	2013-06-14 13:31:52.638	3	f	33	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>jdtt003#13-06-14at15:31:52</clTRID></command></epp>\n	f
66	2013-06-14 13:31:52.638	3	f	33	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>jdtt003#13-06-14at15:31:52</clTRID><svTRID>ReqID-0000000033</svTRID></trID></response></epp>\n	t
67	2013-06-14 13:31:52.769179	3	f	34	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>ekkx001#13-06-14at15:31:52</clTRID></command></epp>\n	f
68	2013-06-14 13:31:52.769179	3	f	34	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>ekkx001#13-06-14at15:31:52</clTRID><svTRID>ReqID-0000000034</svTRID></trID></response></epp>\n	t
69	2013-06-14 13:31:52.827942	3	f	35	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><nsset:create xmlns:nsset="http://www.nic.cz/xml/epp/nsset-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/nsset-1.2 nsset-1.2.xsd"><nsset:id>nssid05</nsset:id><nsset:ns><nsset:name>ns1.domain.cz</nsset:name><nsset:addr>217.31.207.130</nsset:addr><nsset:addr>217.31.207.129</nsset:addr></nsset:ns><nsset:ns><nsset:name>ns2.domain.cz</nsset:name><nsset:addr>217.31.206.130</nsset:addr><nsset:addr>217.31.206.129</nsset:addr></nsset:ns><nsset:tech>TESTER</nsset:tech><nsset:tech>anna</nsset:tech></nsset:create></create><clTRID>ekkx002#13-06-14at15:31:52</clTRID></command></epp>\n	f
70	2013-06-14 13:31:52.827942	3	f	35	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><nsset:creData xmlns:nsset="http://www.nic.cz/xml/epp/nsset-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/nsset-1.2 nsset-1.2.1.xsd"><nsset:id>nssid05</nsset:id><nsset:crDate>2013-06-14T15:31:52+02:00</nsset:crDate></nsset:creData></resData><trID><clTRID>ekkx002#13-06-14at15:31:52</clTRID><svTRID>ReqID-0000000035</svTRID></trID></response></epp>\n	t
71	2013-06-14 13:31:52.940235	3	f	36	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>ekkx003#13-06-14at15:31:52</clTRID></command></epp>\n	f
72	2013-06-14 13:31:52.940235	3	f	36	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>ekkx003#13-06-14at15:31:52</clTRID><svTRID>ReqID-0000000036</svTRID></trID></response></epp>\n	t
73	2013-06-14 13:31:53.060071	3	f	37	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>mwqj001#13-06-14at15:31:53</clTRID></command></epp>\n	f
74	2013-06-14 13:31:53.060071	3	f	37	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>mwqj001#13-06-14at15:31:53</clTRID><svTRID>ReqID-0000000037</svTRID></trID></response></epp>\n	t
75	2013-06-14 13:31:53.119983	3	f	38	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><nsset:create xmlns:nsset="http://www.nic.cz/xml/epp/nsset-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/nsset-1.2 nsset-1.2.xsd"><nsset:id>nssid06</nsset:id><nsset:ns><nsset:name>ns1.domain.cz</nsset:name><nsset:addr>217.31.207.130</nsset:addr><nsset:addr>217.31.207.129</nsset:addr></nsset:ns><nsset:ns><nsset:name>ns2.domain.cz</nsset:name><nsset:addr>217.31.206.130</nsset:addr><nsset:addr>217.31.206.129</nsset:addr></nsset:ns><nsset:tech>TESTER</nsset:tech><nsset:tech>anna</nsset:tech></nsset:create></create><clTRID>mwqj002#13-06-14at15:31:53</clTRID></command></epp>\n	f
76	2013-06-14 13:31:53.119983	3	f	38	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><nsset:creData xmlns:nsset="http://www.nic.cz/xml/epp/nsset-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/nsset-1.2 nsset-1.2.1.xsd"><nsset:id>nssid06</nsset:id><nsset:crDate>2013-06-14T15:31:53+02:00</nsset:crDate></nsset:creData></resData><trID><clTRID>mwqj002#13-06-14at15:31:53</clTRID><svTRID>ReqID-0000000038</svTRID></trID></response></epp>\n	t
77	2013-06-14 13:31:53.229053	3	f	39	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>mwqj003#13-06-14at15:31:53</clTRID></command></epp>\n	f
78	2013-06-14 13:31:53.229053	3	f	39	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>mwqj003#13-06-14at15:31:53</clTRID><svTRID>ReqID-0000000039</svTRID></trID></response></epp>\n	t
79	2013-06-14 13:31:53.356298	3	f	40	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>mpmv001#13-06-14at15:31:53</clTRID></command></epp>\n	f
80	2013-06-14 13:31:53.356298	3	f	40	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>mpmv001#13-06-14at15:31:53</clTRID><svTRID>ReqID-0000000040</svTRID></trID></response></epp>\n	t
81	2013-06-14 13:31:53.415641	3	f	41	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><nsset:create xmlns:nsset="http://www.nic.cz/xml/epp/nsset-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/nsset-1.2 nsset-1.2.xsd"><nsset:id>nssid07</nsset:id><nsset:ns><nsset:name>ns1.domain.cz</nsset:name><nsset:addr>217.31.207.130</nsset:addr><nsset:addr>217.31.207.129</nsset:addr></nsset:ns><nsset:ns><nsset:name>ns2.domain.cz</nsset:name><nsset:addr>217.31.206.130</nsset:addr><nsset:addr>217.31.206.129</nsset:addr></nsset:ns><nsset:tech>TESTER</nsset:tech><nsset:tech>anna</nsset:tech></nsset:create></create><clTRID>mpmv002#13-06-14at15:31:53</clTRID></command></epp>\n	f
82	2013-06-14 13:31:53.415641	3	f	41	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><nsset:creData xmlns:nsset="http://www.nic.cz/xml/epp/nsset-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/nsset-1.2 nsset-1.2.1.xsd"><nsset:id>nssid07</nsset:id><nsset:crDate>2013-06-14T15:31:53+02:00</nsset:crDate></nsset:creData></resData><trID><clTRID>mpmv002#13-06-14at15:31:53</clTRID><svTRID>ReqID-0000000041</svTRID></trID></response></epp>\n	t
83	2013-06-14 13:31:53.525063	3	f	42	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>mpmv003#13-06-14at15:31:53</clTRID></command></epp>\n	f
84	2013-06-14 13:31:53.525063	3	f	42	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>mpmv003#13-06-14at15:31:53</clTRID><svTRID>ReqID-0000000042</svTRID></trID></response></epp>\n	t
85	2013-06-14 13:31:53.650397	3	f	43	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>fdjd001#13-06-14at15:31:53</clTRID></command></epp>\n	f
86	2013-06-14 13:31:53.650397	3	f	43	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>fdjd001#13-06-14at15:31:53</clTRID><svTRID>ReqID-0000000043</svTRID></trID></response></epp>\n	t
87	2013-06-14 13:31:53.70983	3	f	44	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><nsset:create xmlns:nsset="http://www.nic.cz/xml/epp/nsset-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/nsset-1.2 nsset-1.2.xsd"><nsset:id>nssid08</nsset:id><nsset:ns><nsset:name>ns1.domain.cz</nsset:name><nsset:addr>217.31.207.130</nsset:addr><nsset:addr>217.31.207.129</nsset:addr></nsset:ns><nsset:ns><nsset:name>ns2.domain.cz</nsset:name><nsset:addr>217.31.206.130</nsset:addr><nsset:addr>217.31.206.129</nsset:addr></nsset:ns><nsset:tech>TESTER</nsset:tech><nsset:tech>anna</nsset:tech></nsset:create></create><clTRID>fdjd002#13-06-14at15:31:53</clTRID></command></epp>\n	f
88	2013-06-14 13:31:53.70983	3	f	44	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><nsset:creData xmlns:nsset="http://www.nic.cz/xml/epp/nsset-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/nsset-1.2 nsset-1.2.1.xsd"><nsset:id>nssid08</nsset:id><nsset:crDate>2013-06-14T15:31:53+02:00</nsset:crDate></nsset:creData></resData><trID><clTRID>fdjd002#13-06-14at15:31:53</clTRID><svTRID>ReqID-0000000044</svTRID></trID></response></epp>\n	t
89	2013-06-14 13:31:53.818889	3	f	45	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>fdjd003#13-06-14at15:31:53</clTRID></command></epp>\n	f
90	2013-06-14 13:31:53.818889	3	f	45	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>fdjd003#13-06-14at15:31:53</clTRID><svTRID>ReqID-0000000045</svTRID></trID></response></epp>\n	t
91	2013-06-14 13:31:53.948367	3	f	46	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>sluv001#13-06-14at15:31:53</clTRID></command></epp>\n	f
92	2013-06-14 13:31:53.948367	3	f	46	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>sluv001#13-06-14at15:31:53</clTRID><svTRID>ReqID-0000000046</svTRID></trID></response></epp>\n	t
93	2013-06-14 13:31:54.007041	3	f	47	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><nsset:create xmlns:nsset="http://www.nic.cz/xml/epp/nsset-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/nsset-1.2 nsset-1.2.xsd"><nsset:id>nssid09</nsset:id><nsset:ns><nsset:name>ns1.domain.cz</nsset:name><nsset:addr>217.31.207.130</nsset:addr><nsset:addr>217.31.207.129</nsset:addr></nsset:ns><nsset:ns><nsset:name>ns2.domain.cz</nsset:name><nsset:addr>217.31.206.130</nsset:addr><nsset:addr>217.31.206.129</nsset:addr></nsset:ns><nsset:tech>TESTER</nsset:tech><nsset:tech>anna</nsset:tech></nsset:create></create><clTRID>sluv002#13-06-14at15:31:54</clTRID></command></epp>\n	f
94	2013-06-14 13:31:54.007041	3	f	47	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><nsset:creData xmlns:nsset="http://www.nic.cz/xml/epp/nsset-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/nsset-1.2 nsset-1.2.1.xsd"><nsset:id>nssid09</nsset:id><nsset:crDate>2013-06-14T15:31:54+02:00</nsset:crDate></nsset:creData></resData><trID><clTRID>sluv002#13-06-14at15:31:54</clTRID><svTRID>ReqID-0000000047</svTRID></trID></response></epp>\n	t
95	2013-06-14 13:31:54.116438	3	f	48	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>sluv003#13-06-14at15:31:54</clTRID></command></epp>\n	f
96	2013-06-14 13:31:54.116438	3	f	48	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>sluv003#13-06-14at15:31:54</clTRID><svTRID>ReqID-0000000048</svTRID></trID></response></epp>\n	t
97	2013-06-14 13:31:54.235866	3	f	49	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>rqqp001#13-06-14at15:31:54</clTRID></command></epp>\n	f
98	2013-06-14 13:31:54.235866	3	f	49	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>rqqp001#13-06-14at15:31:54</clTRID><svTRID>ReqID-0000000049</svTRID></trID></response></epp>\n	t
99	2013-06-14 13:31:54.296205	3	f	50	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><nsset:create xmlns:nsset="http://www.nic.cz/xml/epp/nsset-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/nsset-1.2 nsset-1.2.xsd"><nsset:id>nssid10</nsset:id><nsset:ns><nsset:name>ns1.domain.cz</nsset:name><nsset:addr>217.31.207.130</nsset:addr><nsset:addr>217.31.207.129</nsset:addr></nsset:ns><nsset:ns><nsset:name>ns2.domain.cz</nsset:name><nsset:addr>217.31.206.130</nsset:addr><nsset:addr>217.31.206.129</nsset:addr></nsset:ns><nsset:tech>TESTER</nsset:tech><nsset:tech>anna</nsset:tech></nsset:create></create><clTRID>rqqp002#13-06-14at15:31:54</clTRID></command></epp>\n	f
100	2013-06-14 13:31:54.296205	3	f	50	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><nsset:creData xmlns:nsset="http://www.nic.cz/xml/epp/nsset-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/nsset-1.2 nsset-1.2.1.xsd"><nsset:id>nssid10</nsset:id><nsset:crDate>2013-06-14T15:31:54+02:00</nsset:crDate></nsset:creData></resData><trID><clTRID>rqqp002#13-06-14at15:31:54</clTRID><svTRID>ReqID-0000000050</svTRID></trID></response></epp>\n	t
101	2013-06-14 13:31:54.405267	3	f	51	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>rqqp003#13-06-14at15:31:54</clTRID></command></epp>\n	f
102	2013-06-14 13:31:54.405267	3	f	51	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>rqqp003#13-06-14at15:31:54</clTRID><svTRID>ReqID-0000000051</svTRID></trID></response></epp>\n	t
103	2013-06-14 13:31:54.533374	3	f	52	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>qlxb001#13-06-14at15:31:54</clTRID></command></epp>\n	f
104	2013-06-14 13:31:54.533374	3	f	52	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>qlxb001#13-06-14at15:31:54</clTRID><svTRID>ReqID-0000000052</svTRID></trID></response></epp>\n	t
105	2013-06-14 13:31:54.591899	3	f	53	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><keyset:create xmlns:keyset="http://www.nic.cz/xml/epp/keyset-1.3" xsi:schemaLocation="http://www.nic.cz/xml/epp/keyset-1.3 keyset-1.3.xsd"><keyset:id>keyid01</keyset:id><keyset:dnskey><keyset:flags>257</keyset:flags><keyset:protocol>3</keyset:protocol><keyset:alg>5</keyset:alg><keyset:pubKey>AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8</keyset:pubKey></keyset:dnskey><keyset:tech>TESTER</keyset:tech><keyset:tech>anna</keyset:tech></keyset:create></create><clTRID>qlxb002#13-06-14at15:31:54</clTRID></command></epp>\n	f
106	2013-06-14 13:31:54.591899	3	f	53	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><keyset:creData xmlns:keyset="http://www.nic.cz/xml/epp/keyset-1.3" xsi:schemaLocation="http://www.nic.cz/xml/epp/keyset-1.3 keyset-1.3.1.xsd"><keyset:id>keyid01</keyset:id><keyset:crDate>2013-06-14T15:31:54+02:00</keyset:crDate></keyset:creData></resData><trID><clTRID>qlxb002#13-06-14at15:31:54</clTRID><svTRID>ReqID-0000000053</svTRID></trID></response></epp>\n	t
107	2013-06-14 13:31:54.688549	3	f	54	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>qlxb003#13-06-14at15:31:54</clTRID></command></epp>\n	f
108	2013-06-14 13:31:54.688549	3	f	54	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>qlxb003#13-06-14at15:31:54</clTRID><svTRID>ReqID-0000000054</svTRID></trID></response></epp>\n	t
109	2013-06-14 13:31:54.817635	3	f	55	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>stsl001#13-06-14at15:31:54</clTRID></command></epp>\n	f
110	2013-06-14 13:31:54.817635	3	f	55	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>stsl001#13-06-14at15:31:54</clTRID><svTRID>ReqID-0000000055</svTRID></trID></response></epp>\n	t
111	2013-06-14 13:31:54.875497	3	f	56	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><keyset:create xmlns:keyset="http://www.nic.cz/xml/epp/keyset-1.3" xsi:schemaLocation="http://www.nic.cz/xml/epp/keyset-1.3 keyset-1.3.xsd"><keyset:id>keyid02</keyset:id><keyset:dnskey><keyset:flags>257</keyset:flags><keyset:protocol>3</keyset:protocol><keyset:alg>5</keyset:alg><keyset:pubKey>AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8</keyset:pubKey></keyset:dnskey><keyset:tech>TESTER</keyset:tech><keyset:tech>anna</keyset:tech></keyset:create></create><clTRID>stsl002#13-06-14at15:31:54</clTRID></command></epp>\n	f
112	2013-06-14 13:31:54.875497	3	f	56	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><keyset:creData xmlns:keyset="http://www.nic.cz/xml/epp/keyset-1.3" xsi:schemaLocation="http://www.nic.cz/xml/epp/keyset-1.3 keyset-1.3.1.xsd"><keyset:id>keyid02</keyset:id><keyset:crDate>2013-06-14T15:31:54+02:00</keyset:crDate></keyset:creData></resData><trID><clTRID>stsl002#13-06-14at15:31:54</clTRID><svTRID>ReqID-0000000056</svTRID></trID></response></epp>\n	t
113	2013-06-14 13:31:54.950894	3	f	57	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>stsl003#13-06-14at15:31:54</clTRID></command></epp>\n	f
114	2013-06-14 13:31:54.950894	3	f	57	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>stsl003#13-06-14at15:31:54</clTRID><svTRID>ReqID-0000000057</svTRID></trID></response></epp>\n	t
115	2013-06-14 13:31:55.076237	3	f	58	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>mwwm001#13-06-14at15:31:55</clTRID></command></epp>\n	f
116	2013-06-14 13:31:55.076237	3	f	58	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>mwwm001#13-06-14at15:31:55</clTRID><svTRID>ReqID-0000000058</svTRID></trID></response></epp>\n	t
117	2013-06-14 13:31:55.135419	3	f	59	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><keyset:create xmlns:keyset="http://www.nic.cz/xml/epp/keyset-1.3" xsi:schemaLocation="http://www.nic.cz/xml/epp/keyset-1.3 keyset-1.3.xsd"><keyset:id>keyid03</keyset:id><keyset:dnskey><keyset:flags>257</keyset:flags><keyset:protocol>3</keyset:protocol><keyset:alg>5</keyset:alg><keyset:pubKey>AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8</keyset:pubKey></keyset:dnskey><keyset:tech>TESTER</keyset:tech><keyset:tech>anna</keyset:tech></keyset:create></create><clTRID>mwwm002#13-06-14at15:31:55</clTRID></command></epp>\n	f
118	2013-06-14 13:31:55.135419	3	f	59	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><keyset:creData xmlns:keyset="http://www.nic.cz/xml/epp/keyset-1.3" xsi:schemaLocation="http://www.nic.cz/xml/epp/keyset-1.3 keyset-1.3.1.xsd"><keyset:id>keyid03</keyset:id><keyset:crDate>2013-06-14T15:31:55+02:00</keyset:crDate></keyset:creData></resData><trID><clTRID>mwwm002#13-06-14at15:31:55</clTRID><svTRID>ReqID-0000000059</svTRID></trID></response></epp>\n	t
119	2013-06-14 13:31:55.23132	3	f	60	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>mwwm003#13-06-14at15:31:55</clTRID></command></epp>\n	f
120	2013-06-14 13:31:55.23132	3	f	60	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>mwwm003#13-06-14at15:31:55</clTRID><svTRID>ReqID-0000000060</svTRID></trID></response></epp>\n	t
121	2013-06-14 13:31:55.352745	3	f	61	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>gtbn001#13-06-14at15:31:55</clTRID></command></epp>\n	f
122	2013-06-14 13:31:55.352745	3	f	61	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>gtbn001#13-06-14at15:31:55</clTRID><svTRID>ReqID-0000000061</svTRID></trID></response></epp>\n	t
123	2013-06-14 13:31:55.413411	3	f	62	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><keyset:create xmlns:keyset="http://www.nic.cz/xml/epp/keyset-1.3" xsi:schemaLocation="http://www.nic.cz/xml/epp/keyset-1.3 keyset-1.3.xsd"><keyset:id>keyid04</keyset:id><keyset:dnskey><keyset:flags>257</keyset:flags><keyset:protocol>3</keyset:protocol><keyset:alg>5</keyset:alg><keyset:pubKey>AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8</keyset:pubKey></keyset:dnskey><keyset:tech>TESTER</keyset:tech><keyset:tech>anna</keyset:tech></keyset:create></create><clTRID>gtbn002#13-06-14at15:31:55</clTRID></command></epp>\n	f
124	2013-06-14 13:31:55.413411	3	f	62	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><keyset:creData xmlns:keyset="http://www.nic.cz/xml/epp/keyset-1.3" xsi:schemaLocation="http://www.nic.cz/xml/epp/keyset-1.3 keyset-1.3.1.xsd"><keyset:id>keyid04</keyset:id><keyset:crDate>2013-06-14T15:31:55+02:00</keyset:crDate></keyset:creData></resData><trID><clTRID>gtbn002#13-06-14at15:31:55</clTRID><svTRID>ReqID-0000000062</svTRID></trID></response></epp>\n	t
125	2013-06-14 13:31:55.509039	3	f	63	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>gtbn003#13-06-14at15:31:55</clTRID></command></epp>\n	f
126	2013-06-14 13:31:55.509039	3	f	63	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>gtbn003#13-06-14at15:31:55</clTRID><svTRID>ReqID-0000000063</svTRID></trID></response></epp>\n	t
127	2013-06-14 13:31:55.637527	3	f	64	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>vxjb001#13-06-14at15:31:55</clTRID></command></epp>\n	f
128	2013-06-14 13:31:55.637527	3	f	64	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>vxjb001#13-06-14at15:31:55</clTRID><svTRID>ReqID-0000000064</svTRID></trID></response></epp>\n	t
129	2013-06-14 13:31:55.696654	3	f	65	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><keyset:create xmlns:keyset="http://www.nic.cz/xml/epp/keyset-1.3" xsi:schemaLocation="http://www.nic.cz/xml/epp/keyset-1.3 keyset-1.3.xsd"><keyset:id>keyid05</keyset:id><keyset:dnskey><keyset:flags>257</keyset:flags><keyset:protocol>3</keyset:protocol><keyset:alg>5</keyset:alg><keyset:pubKey>AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8</keyset:pubKey></keyset:dnskey><keyset:tech>TESTER</keyset:tech><keyset:tech>anna</keyset:tech></keyset:create></create><clTRID>vxjb002#13-06-14at15:31:55</clTRID></command></epp>\n	f
130	2013-06-14 13:31:55.696654	3	f	65	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><keyset:creData xmlns:keyset="http://www.nic.cz/xml/epp/keyset-1.3" xsi:schemaLocation="http://www.nic.cz/xml/epp/keyset-1.3 keyset-1.3.1.xsd"><keyset:id>keyid05</keyset:id><keyset:crDate>2013-06-14T15:31:55+02:00</keyset:crDate></keyset:creData></resData><trID><clTRID>vxjb002#13-06-14at15:31:55</clTRID><svTRID>ReqID-0000000065</svTRID></trID></response></epp>\n	t
131	2013-06-14 13:31:55.792083	3	f	66	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>vxjb003#13-06-14at15:31:55</clTRID></command></epp>\n	f
132	2013-06-14 13:31:55.792083	3	f	66	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>vxjb003#13-06-14at15:31:55</clTRID><svTRID>ReqID-0000000066</svTRID></trID></response></epp>\n	t
133	2013-06-14 13:31:55.918068	3	f	67	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>lpeq001#13-06-14at15:31:55</clTRID></command></epp>\n	f
134	2013-06-14 13:31:55.918068	3	f	67	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>lpeq001#13-06-14at15:31:55</clTRID><svTRID>ReqID-0000000067</svTRID></trID></response></epp>\n	t
135	2013-06-14 13:31:55.976723	3	f	68	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><keyset:create xmlns:keyset="http://www.nic.cz/xml/epp/keyset-1.3" xsi:schemaLocation="http://www.nic.cz/xml/epp/keyset-1.3 keyset-1.3.xsd"><keyset:id>keyid06</keyset:id><keyset:dnskey><keyset:flags>257</keyset:flags><keyset:protocol>3</keyset:protocol><keyset:alg>5</keyset:alg><keyset:pubKey>AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8</keyset:pubKey></keyset:dnskey><keyset:tech>TESTER</keyset:tech><keyset:tech>anna</keyset:tech></keyset:create></create><clTRID>lpeq002#13-06-14at15:31:55</clTRID></command></epp>\n	f
136	2013-06-14 13:31:55.976723	3	f	68	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><keyset:creData xmlns:keyset="http://www.nic.cz/xml/epp/keyset-1.3" xsi:schemaLocation="http://www.nic.cz/xml/epp/keyset-1.3 keyset-1.3.1.xsd"><keyset:id>keyid06</keyset:id><keyset:crDate>2013-06-14T15:31:56+02:00</keyset:crDate></keyset:creData></resData><trID><clTRID>lpeq002#13-06-14at15:31:55</clTRID><svTRID>ReqID-0000000068</svTRID></trID></response></epp>\n	t
137	2013-06-14 13:31:56.073097	3	f	69	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>lpeq003#13-06-14at15:31:56</clTRID></command></epp>\n	f
138	2013-06-14 13:31:56.073097	3	f	69	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>lpeq003#13-06-14at15:31:56</clTRID><svTRID>ReqID-0000000069</svTRID></trID></response></epp>\n	t
139	2013-06-14 13:31:56.193554	3	f	70	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>cjpd001#13-06-14at15:31:56</clTRID></command></epp>\n	f
140	2013-06-14 13:31:56.193554	3	f	70	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>cjpd001#13-06-14at15:31:56</clTRID><svTRID>ReqID-0000000070</svTRID></trID></response></epp>\n	t
141	2013-06-14 13:31:56.252318	3	f	71	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><keyset:create xmlns:keyset="http://www.nic.cz/xml/epp/keyset-1.3" xsi:schemaLocation="http://www.nic.cz/xml/epp/keyset-1.3 keyset-1.3.xsd"><keyset:id>keyid07</keyset:id><keyset:dnskey><keyset:flags>257</keyset:flags><keyset:protocol>3</keyset:protocol><keyset:alg>5</keyset:alg><keyset:pubKey>AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8</keyset:pubKey></keyset:dnskey><keyset:tech>TESTER</keyset:tech><keyset:tech>anna</keyset:tech></keyset:create></create><clTRID>cjpd002#13-06-14at15:31:56</clTRID></command></epp>\n	f
142	2013-06-14 13:31:56.252318	3	f	71	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><keyset:creData xmlns:keyset="http://www.nic.cz/xml/epp/keyset-1.3" xsi:schemaLocation="http://www.nic.cz/xml/epp/keyset-1.3 keyset-1.3.1.xsd"><keyset:id>keyid07</keyset:id><keyset:crDate>2013-06-14T15:31:56+02:00</keyset:crDate></keyset:creData></resData><trID><clTRID>cjpd002#13-06-14at15:31:56</clTRID><svTRID>ReqID-0000000071</svTRID></trID></response></epp>\n	t
143	2013-06-14 13:31:56.348027	3	f	72	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>cjpd003#13-06-14at15:31:56</clTRID></command></epp>\n	f
144	2013-06-14 13:31:56.348027	3	f	72	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>cjpd003#13-06-14at15:31:56</clTRID><svTRID>ReqID-0000000072</svTRID></trID></response></epp>\n	t
145	2013-06-14 13:31:56.474393	3	f	73	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>wlmd001#13-06-14at15:31:56</clTRID></command></epp>\n	f
146	2013-06-14 13:31:56.474393	3	f	73	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>wlmd001#13-06-14at15:31:56</clTRID><svTRID>ReqID-0000000073</svTRID></trID></response></epp>\n	t
147	2013-06-14 13:31:56.53354	3	f	74	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><keyset:create xmlns:keyset="http://www.nic.cz/xml/epp/keyset-1.3" xsi:schemaLocation="http://www.nic.cz/xml/epp/keyset-1.3 keyset-1.3.xsd"><keyset:id>keyid08</keyset:id><keyset:dnskey><keyset:flags>257</keyset:flags><keyset:protocol>3</keyset:protocol><keyset:alg>5</keyset:alg><keyset:pubKey>AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8</keyset:pubKey></keyset:dnskey><keyset:tech>TESTER</keyset:tech><keyset:tech>anna</keyset:tech></keyset:create></create><clTRID>wlmd002#13-06-14at15:31:56</clTRID></command></epp>\n	f
148	2013-06-14 13:31:56.53354	3	f	74	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><keyset:creData xmlns:keyset="http://www.nic.cz/xml/epp/keyset-1.3" xsi:schemaLocation="http://www.nic.cz/xml/epp/keyset-1.3 keyset-1.3.1.xsd"><keyset:id>keyid08</keyset:id><keyset:crDate>2013-06-14T15:31:56+02:00</keyset:crDate></keyset:creData></resData><trID><clTRID>wlmd002#13-06-14at15:31:56</clTRID><svTRID>ReqID-0000000074</svTRID></trID></response></epp>\n	t
149	2013-06-14 13:31:56.630762	3	f	75	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>wlmd003#13-06-14at15:31:56</clTRID></command></epp>\n	f
150	2013-06-14 13:31:56.630762	3	f	75	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>wlmd003#13-06-14at15:31:56</clTRID><svTRID>ReqID-0000000075</svTRID></trID></response></epp>\n	t
151	2013-06-14 13:31:56.756571	3	f	76	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>przn001#13-06-14at15:31:56</clTRID></command></epp>\n	f
152	2013-06-14 13:31:56.756571	3	f	76	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>przn001#13-06-14at15:31:56</clTRID><svTRID>ReqID-0000000076</svTRID></trID></response></epp>\n	t
153	2013-06-14 13:31:56.815828	3	f	77	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><keyset:create xmlns:keyset="http://www.nic.cz/xml/epp/keyset-1.3" xsi:schemaLocation="http://www.nic.cz/xml/epp/keyset-1.3 keyset-1.3.xsd"><keyset:id>keyid09</keyset:id><keyset:dnskey><keyset:flags>257</keyset:flags><keyset:protocol>3</keyset:protocol><keyset:alg>5</keyset:alg><keyset:pubKey>AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8</keyset:pubKey></keyset:dnskey><keyset:tech>TESTER</keyset:tech><keyset:tech>anna</keyset:tech></keyset:create></create><clTRID>przn002#13-06-14at15:31:56</clTRID></command></epp>\n	f
154	2013-06-14 13:31:56.815828	3	f	77	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><keyset:creData xmlns:keyset="http://www.nic.cz/xml/epp/keyset-1.3" xsi:schemaLocation="http://www.nic.cz/xml/epp/keyset-1.3 keyset-1.3.1.xsd"><keyset:id>keyid09</keyset:id><keyset:crDate>2013-06-14T15:31:56+02:00</keyset:crDate></keyset:creData></resData><trID><clTRID>przn002#13-06-14at15:31:56</clTRID><svTRID>ReqID-0000000077</svTRID></trID></response></epp>\n	t
155	2013-06-14 13:31:56.91392	3	f	78	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>przn003#13-06-14at15:31:56</clTRID></command></epp>\n	f
156	2013-06-14 13:31:56.91392	3	f	78	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>przn003#13-06-14at15:31:56</clTRID><svTRID>ReqID-0000000078</svTRID></trID></response></epp>\n	t
157	2013-06-14 13:31:57.037095	3	f	79	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>jydo001#13-06-14at15:31:57</clTRID></command></epp>\n	f
158	2013-06-14 13:31:57.037095	3	f	79	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>jydo001#13-06-14at15:31:57</clTRID><svTRID>ReqID-0000000079</svTRID></trID></response></epp>\n	t
159	2013-06-14 13:31:57.099624	3	f	80	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><keyset:create xmlns:keyset="http://www.nic.cz/xml/epp/keyset-1.3" xsi:schemaLocation="http://www.nic.cz/xml/epp/keyset-1.3 keyset-1.3.xsd"><keyset:id>keyid10</keyset:id><keyset:dnskey><keyset:flags>257</keyset:flags><keyset:protocol>3</keyset:protocol><keyset:alg>5</keyset:alg><keyset:pubKey>AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8</keyset:pubKey></keyset:dnskey><keyset:tech>TESTER</keyset:tech><keyset:tech>anna</keyset:tech></keyset:create></create><clTRID>jydo002#13-06-14at15:31:57</clTRID></command></epp>\n	f
160	2013-06-14 13:31:57.099624	3	f	80	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><keyset:creData xmlns:keyset="http://www.nic.cz/xml/epp/keyset-1.3" xsi:schemaLocation="http://www.nic.cz/xml/epp/keyset-1.3 keyset-1.3.1.xsd"><keyset:id>keyid10</keyset:id><keyset:crDate>2013-06-14T15:31:57+02:00</keyset:crDate></keyset:creData></resData><trID><clTRID>jydo002#13-06-14at15:31:57</clTRID><svTRID>ReqID-0000000080</svTRID></trID></response></epp>\n	t
161	2013-06-14 13:31:57.195262	3	f	81	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>jydo003#13-06-14at15:31:57</clTRID></command></epp>\n	f
162	2013-06-14 13:31:57.195262	3	f	81	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>jydo003#13-06-14at15:31:57</clTRID><svTRID>ReqID-0000000081</svTRID></trID></response></epp>\n	t
163	2013-06-14 13:31:57.314593	3	f	82	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>bupo001#13-06-14at15:31:57</clTRID></command></epp>\n	f
164	2013-06-14 13:31:57.314593	3	f	82	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>bupo001#13-06-14at15:31:57</clTRID><svTRID>ReqID-0000000082</svTRID></trID></response></epp>\n	t
165	2013-06-14 13:31:57.367545	3	f	83	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>nic01.cz</domain:name><domain:period unit="y">3</domain:period><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>TESTER</domain:registrant><domain:admin>anna</domain:admin><domain:admin>TESTER</domain:admin><domain:authInfo>heslo</domain:authInfo></domain:create></create><clTRID>bupo002#13-06-14at15:31:57</clTRID></command></epp>\n	f
166	2013-06-14 13:31:57.367545	3	f	83	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>nic01.cz</domain:name><domain:crDate>2013-06-14T15:31:57+02:00</domain:crDate><domain:exDate>2016-06-14</domain:exDate></domain:creData></resData><trID><clTRID>bupo002#13-06-14at15:31:57</clTRID><svTRID>ReqID-0000000083</svTRID></trID></response></epp>\n	t
167	2013-06-14 13:31:57.497802	3	f	84	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>bupo003#13-06-14at15:31:57</clTRID></command></epp>\n	f
168	2013-06-14 13:31:57.497802	3	f	84	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>bupo003#13-06-14at15:31:57</clTRID><svTRID>ReqID-0000000084</svTRID></trID></response></epp>\n	t
169	2013-06-14 13:31:57.615419	3	f	85	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>usbd001#13-06-14at15:31:57</clTRID></command></epp>\n	f
170	2013-06-14 13:31:57.615419	3	f	85	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>usbd001#13-06-14at15:31:57</clTRID><svTRID>ReqID-0000000085</svTRID></trID></response></epp>\n	t
171	2013-06-14 13:31:57.67431	3	f	86	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>nic02.cz</domain:name><domain:period unit="y">3</domain:period><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>TESTER</domain:registrant><domain:admin>anna</domain:admin><domain:admin>TESTER</domain:admin><domain:authInfo>heslo</domain:authInfo></domain:create></create><clTRID>usbd002#13-06-14at15:31:57</clTRID></command></epp>\n	f
172	2013-06-14 13:31:57.67431	3	f	86	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>nic02.cz</domain:name><domain:crDate>2013-06-14T15:31:57+02:00</domain:crDate><domain:exDate>2016-06-14</domain:exDate></domain:creData></resData><trID><clTRID>usbd002#13-06-14at15:31:57</clTRID><svTRID>ReqID-0000000086</svTRID></trID></response></epp>\n	t
173	2013-06-14 13:31:57.799648	3	f	87	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>usbd003#13-06-14at15:31:57</clTRID></command></epp>\n	f
174	2013-06-14 13:31:57.799648	3	f	87	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>usbd003#13-06-14at15:31:57</clTRID><svTRID>ReqID-0000000087</svTRID></trID></response></epp>\n	t
175	2013-06-14 13:31:57.930438	3	f	88	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>tawu001#13-06-14at15:31:57</clTRID></command></epp>\n	f
176	2013-06-14 13:31:57.930438	3	f	88	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>tawu001#13-06-14at15:31:57</clTRID><svTRID>ReqID-0000000088</svTRID></trID></response></epp>\n	t
177	2013-06-14 13:31:57.989386	3	f	89	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>nic03.cz</domain:name><domain:period unit="y">3</domain:period><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>TESTER</domain:registrant><domain:admin>anna</domain:admin><domain:admin>TESTER</domain:admin><domain:authInfo>heslo</domain:authInfo></domain:create></create><clTRID>tawu002#13-06-14at15:31:57</clTRID></command></epp>\n	f
178	2013-06-14 13:31:57.989386	3	f	89	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>nic03.cz</domain:name><domain:crDate>2013-06-14T15:31:58+02:00</domain:crDate><domain:exDate>2016-06-14</domain:exDate></domain:creData></resData><trID><clTRID>tawu002#13-06-14at15:31:57</clTRID><svTRID>ReqID-0000000089</svTRID></trID></response></epp>\n	t
179	2013-06-14 13:31:58.115984	3	f	90	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>tawu003#13-06-14at15:31:58</clTRID></command></epp>\n	f
180	2013-06-14 13:31:58.115984	3	f	90	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>tawu003#13-06-14at15:31:58</clTRID><svTRID>ReqID-0000000090</svTRID></trID></response></epp>\n	t
181	2013-06-14 13:31:58.249341	3	f	91	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>wgrr001#13-06-14at15:31:58</clTRID></command></epp>\n	f
182	2013-06-14 13:31:58.249341	3	f	91	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>wgrr001#13-06-14at15:31:58</clTRID><svTRID>ReqID-0000000091</svTRID></trID></response></epp>\n	t
183	2013-06-14 13:31:58.308432	3	f	92	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>nic04.cz</domain:name><domain:period unit="y">3</domain:period><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>TESTER</domain:registrant><domain:admin>anna</domain:admin><domain:admin>TESTER</domain:admin><domain:authInfo>heslo</domain:authInfo></domain:create></create><clTRID>wgrr002#13-06-14at15:31:58</clTRID></command></epp>\n	f
184	2013-06-14 13:31:58.308432	3	f	92	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>nic04.cz</domain:name><domain:crDate>2013-06-14T15:31:58+02:00</domain:crDate><domain:exDate>2016-06-14</domain:exDate></domain:creData></resData><trID><clTRID>wgrr002#13-06-14at15:31:58</clTRID><svTRID>ReqID-0000000092</svTRID></trID></response></epp>\n	t
185	2013-06-14 13:31:58.434833	3	f	93	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>wgrr003#13-06-14at15:31:58</clTRID></command></epp>\n	f
186	2013-06-14 13:31:58.434833	3	f	93	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>wgrr003#13-06-14at15:31:58</clTRID><svTRID>ReqID-0000000093</svTRID></trID></response></epp>\n	t
187	2013-06-14 13:31:58.557735	3	f	94	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>unzb001#13-06-14at15:31:58</clTRID></command></epp>\n	f
188	2013-06-14 13:31:58.557735	3	f	94	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>unzb001#13-06-14at15:31:58</clTRID><svTRID>ReqID-0000000094</svTRID></trID></response></epp>\n	t
189	2013-06-14 13:31:58.621642	3	f	95	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>nic05.cz</domain:name><domain:period unit="y">3</domain:period><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>TESTER</domain:registrant><domain:admin>anna</domain:admin><domain:admin>TESTER</domain:admin><domain:authInfo>heslo</domain:authInfo></domain:create></create><clTRID>unzb002#13-06-14at15:31:58</clTRID></command></epp>\n	f
190	2013-06-14 13:31:58.621642	3	f	95	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>nic05.cz</domain:name><domain:crDate>2013-06-14T15:31:58+02:00</domain:crDate><domain:exDate>2016-06-14</domain:exDate></domain:creData></resData><trID><clTRID>unzb002#13-06-14at15:31:58</clTRID><svTRID>ReqID-0000000095</svTRID></trID></response></epp>\n	t
191	2013-06-14 13:31:58.747057	3	f	96	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>unzb003#13-06-14at15:31:58</clTRID></command></epp>\n	f
192	2013-06-14 13:31:58.747057	3	f	96	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>unzb003#13-06-14at15:31:58</clTRID><svTRID>ReqID-0000000096</svTRID></trID></response></epp>\n	t
193	2013-06-14 13:31:58.868199	3	f	97	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>rgwq001#13-06-14at15:31:58</clTRID></command></epp>\n	f
194	2013-06-14 13:31:58.868199	3	f	97	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>rgwq001#13-06-14at15:31:58</clTRID><svTRID>ReqID-0000000097</svTRID></trID></response></epp>\n	t
195	2013-06-14 13:31:58.927217	3	f	98	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>nic06.cz</domain:name><domain:period unit="y">3</domain:period><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>TESTER</domain:registrant><domain:admin>anna</domain:admin><domain:admin>TESTER</domain:admin><domain:authInfo>heslo</domain:authInfo></domain:create></create><clTRID>rgwq002#13-06-14at15:31:58</clTRID></command></epp>\n	f
196	2013-06-14 13:31:58.927217	3	f	98	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>nic06.cz</domain:name><domain:crDate>2013-06-14T15:31:58+02:00</domain:crDate><domain:exDate>2016-06-14</domain:exDate></domain:creData></resData><trID><clTRID>rgwq002#13-06-14at15:31:58</clTRID><svTRID>ReqID-0000000098</svTRID></trID></response></epp>\n	t
197	2013-06-14 13:31:59.055859	3	f	99	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>rgwq003#13-06-14at15:31:59</clTRID></command></epp>\n	f
198	2013-06-14 13:31:59.055859	3	f	99	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>rgwq003#13-06-14at15:31:59</clTRID><svTRID>ReqID-0000000099</svTRID></trID></response></epp>\n	t
199	2013-06-14 13:31:59.178127	3	f	100	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>cywy001#13-06-14at15:31:59</clTRID></command></epp>\n	f
200	2013-06-14 13:31:59.178127	3	f	100	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>cywy001#13-06-14at15:31:59</clTRID><svTRID>ReqID-0000000100</svTRID></trID></response></epp>\n	t
201	2013-06-14 13:31:59.237565	3	f	101	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>nic07.cz</domain:name><domain:period unit="y">3</domain:period><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>TESTER</domain:registrant><domain:admin>anna</domain:admin><domain:admin>TESTER</domain:admin><domain:authInfo>heslo</domain:authInfo></domain:create></create><clTRID>cywy002#13-06-14at15:31:59</clTRID></command></epp>\n	f
202	2013-06-14 13:31:59.237565	3	f	101	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>nic07.cz</domain:name><domain:crDate>2013-06-14T15:31:59+02:00</domain:crDate><domain:exDate>2016-06-14</domain:exDate></domain:creData></resData><trID><clTRID>cywy002#13-06-14at15:31:59</clTRID><svTRID>ReqID-0000000101</svTRID></trID></response></epp>\n	t
203	2013-06-14 13:31:59.364126	3	f	102	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>cywy003#13-06-14at15:31:59</clTRID></command></epp>\n	f
204	2013-06-14 13:31:59.364126	3	f	102	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>cywy003#13-06-14at15:31:59</clTRID><svTRID>ReqID-0000000102</svTRID></trID></response></epp>\n	t
205	2013-06-14 13:31:59.488069	3	f	103	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>rcfx001#13-06-14at15:31:59</clTRID></command></epp>\n	f
206	2013-06-14 13:31:59.488069	3	f	103	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>rcfx001#13-06-14at15:31:59</clTRID><svTRID>ReqID-0000000103</svTRID></trID></response></epp>\n	t
207	2013-06-14 13:31:59.54742	3	f	104	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>nic08.cz</domain:name><domain:period unit="y">3</domain:period><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>TESTER</domain:registrant><domain:admin>anna</domain:admin><domain:admin>TESTER</domain:admin><domain:authInfo>heslo</domain:authInfo></domain:create></create><clTRID>rcfx002#13-06-14at15:31:59</clTRID></command></epp>\n	f
208	2013-06-14 13:31:59.54742	3	f	104	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>nic08.cz</domain:name><domain:crDate>2013-06-14T15:31:59+02:00</domain:crDate><domain:exDate>2016-06-14</domain:exDate></domain:creData></resData><trID><clTRID>rcfx002#13-06-14at15:31:59</clTRID><svTRID>ReqID-0000000104</svTRID></trID></response></epp>\n	t
209	2013-06-14 13:31:59.678123	3	f	105	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>rcfx003#13-06-14at15:31:59</clTRID></command></epp>\n	f
210	2013-06-14 13:31:59.678123	3	f	105	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>rcfx003#13-06-14at15:31:59</clTRID><svTRID>ReqID-0000000105</svTRID></trID></response></epp>\n	t
211	2013-06-14 13:31:59.799385	3	f	106	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>gyxz001#13-06-14at15:31:59</clTRID></command></epp>\n	f
212	2013-06-14 13:31:59.799385	3	f	106	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>gyxz001#13-06-14at15:31:59</clTRID><svTRID>ReqID-0000000106</svTRID></trID></response></epp>\n	t
213	2013-06-14 13:31:59.858572	3	f	107	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>nic09.cz</domain:name><domain:period unit="y">3</domain:period><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>TESTER</domain:registrant><domain:admin>anna</domain:admin><domain:admin>TESTER</domain:admin><domain:authInfo>heslo</domain:authInfo></domain:create></create><clTRID>gyxz002#13-06-14at15:31:59</clTRID></command></epp>\n	f
214	2013-06-14 13:31:59.858572	3	f	107	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>nic09.cz</domain:name><domain:crDate>2013-06-14T15:31:59+02:00</domain:crDate><domain:exDate>2016-06-14</domain:exDate></domain:creData></resData><trID><clTRID>gyxz002#13-06-14at15:31:59</clTRID><svTRID>ReqID-0000000107</svTRID></trID></response></epp>\n	t
215	2013-06-14 13:31:59.984729	3	f	108	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>gyxz003#13-06-14at15:31:59</clTRID></command></epp>\n	f
216	2013-06-14 13:31:59.984729	3	f	108	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>gyxz003#13-06-14at15:31:59</clTRID><svTRID>ReqID-0000000108</svTRID></trID></response></epp>\n	t
217	2013-06-14 13:32:00.10372	3	f	109	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>bfhp001#13-06-14at15:32:00</clTRID></command></epp>\n	f
218	2013-06-14 13:32:00.10372	3	f	109	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>bfhp001#13-06-14at15:32:00</clTRID><svTRID>ReqID-0000000109</svTRID></trID></response></epp>\n	t
219	2013-06-14 13:32:00.163381	3	f	110	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>nic10.cz</domain:name><domain:period unit="y">3</domain:period><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>TESTER</domain:registrant><domain:admin>anna</domain:admin><domain:admin>TESTER</domain:admin><domain:authInfo>heslo</domain:authInfo></domain:create></create><clTRID>bfhp002#13-06-14at15:32:00</clTRID></command></epp>\n	f
220	2013-06-14 13:32:00.163381	3	f	110	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>nic10.cz</domain:name><domain:crDate>2013-06-14T15:32:00+02:00</domain:crDate><domain:exDate>2016-06-14</domain:exDate></domain:creData></resData><trID><clTRID>bfhp002#13-06-14at15:32:00</clTRID><svTRID>ReqID-0000000110</svTRID></trID></response></epp>\n	t
221	2013-06-14 13:32:00.290621	3	f	111	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>bfhp003#13-06-14at15:32:00</clTRID></command></epp>\n	f
222	2013-06-14 13:32:00.290621	3	f	111	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>bfhp003#13-06-14at15:32:00</clTRID><svTRID>ReqID-0000000111</svTRID></trID></response></epp>\n	t
223	2013-06-14 13:32:00.411361	3	f	112	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>cpbg001#13-06-14at15:32:00</clTRID></command></epp>\n	f
224	2013-06-14 13:32:00.411361	3	f	112	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>cpbg001#13-06-14at15:32:00</clTRID><svTRID>ReqID-0000000112</svTRID></trID></response></epp>\n	t
225	2013-06-14 13:32:00.470148	3	f	113	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>ginger01.cz</domain:name><domain:period unit="y">3</domain:period><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>anna</domain:registrant><domain:admin>TESTER</domain:admin><domain:authInfo>heslo</domain:authInfo></domain:create></create><clTRID>cpbg002#13-06-14at15:32:00</clTRID></command></epp>\n	f
226	2013-06-14 13:32:00.470148	3	f	113	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>ginger01.cz</domain:name><domain:crDate>2013-06-14T15:32:00+02:00</domain:crDate><domain:exDate>2016-06-14</domain:exDate></domain:creData></resData><trID><clTRID>cpbg002#13-06-14at15:32:00</clTRID><svTRID>ReqID-0000000113</svTRID></trID></response></epp>\n	t
227	2013-06-14 13:32:00.590745	3	f	114	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>cpbg003#13-06-14at15:32:00</clTRID></command></epp>\n	f
228	2013-06-14 13:32:00.590745	3	f	114	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>cpbg003#13-06-14at15:32:00</clTRID><svTRID>ReqID-0000000114</svTRID></trID></response></epp>\n	t
229	2013-06-14 13:32:00.710188	3	f	115	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>aknx001#13-06-14at15:32:00</clTRID></command></epp>\n	f
230	2013-06-14 13:32:00.710188	3	f	115	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>aknx001#13-06-14at15:32:00</clTRID><svTRID>ReqID-0000000115</svTRID></trID></response></epp>\n	t
231	2013-06-14 13:32:00.76986	3	f	116	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>ginger02.cz</domain:name><domain:period unit="y">3</domain:period><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>anna</domain:registrant><domain:admin>TESTER</domain:admin><domain:authInfo>heslo</domain:authInfo></domain:create></create><clTRID>aknx002#13-06-14at15:32:00</clTRID></command></epp>\n	f
232	2013-06-14 13:32:00.76986	3	f	116	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>ginger02.cz</domain:name><domain:crDate>2013-06-14T15:32:00+02:00</domain:crDate><domain:exDate>2016-06-14</domain:exDate></domain:creData></resData><trID><clTRID>aknx002#13-06-14at15:32:00</clTRID><svTRID>ReqID-0000000116</svTRID></trID></response></epp>\n	t
233	2013-06-14 13:32:00.89147	3	f	117	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>aknx003#13-06-14at15:32:00</clTRID></command></epp>\n	f
234	2013-06-14 13:32:00.89147	3	f	117	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>aknx003#13-06-14at15:32:00</clTRID><svTRID>ReqID-0000000117</svTRID></trID></response></epp>\n	t
235	2013-06-14 13:32:01.015982	3	f	118	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>trta001#13-06-14at15:32:01</clTRID></command></epp>\n	f
236	2013-06-14 13:32:01.015982	3	f	118	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>trta001#13-06-14at15:32:01</clTRID><svTRID>ReqID-0000000118</svTRID></trID></response></epp>\n	t
237	2013-06-14 13:32:01.07493	3	f	119	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>ginger03.cz</domain:name><domain:period unit="y">3</domain:period><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>anna</domain:registrant><domain:admin>TESTER</domain:admin><domain:authInfo>heslo</domain:authInfo></domain:create></create><clTRID>trta002#13-06-14at15:32:01</clTRID></command></epp>\n	f
238	2013-06-14 13:32:01.07493	3	f	119	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>ginger03.cz</domain:name><domain:crDate>2013-06-14T15:32:01+02:00</domain:crDate><domain:exDate>2016-06-14</domain:exDate></domain:creData></resData><trID><clTRID>trta002#13-06-14at15:32:01</clTRID><svTRID>ReqID-0000000119</svTRID></trID></response></epp>\n	t
239	2013-06-14 13:32:01.196397	3	f	120	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>trta003#13-06-14at15:32:01</clTRID></command></epp>\n	f
240	2013-06-14 13:32:01.196397	3	f	120	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>trta003#13-06-14at15:32:01</clTRID><svTRID>ReqID-0000000120</svTRID></trID></response></epp>\n	t
241	2013-06-14 13:32:01.328519	3	f	121	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>djmf001#13-06-14at15:32:01</clTRID></command></epp>\n	f
242	2013-06-14 13:32:01.328519	3	f	121	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>djmf001#13-06-14at15:32:01</clTRID><svTRID>ReqID-0000000121</svTRID></trID></response></epp>\n	t
243	2013-06-14 13:32:01.387742	3	f	122	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>ginger04.cz</domain:name><domain:period unit="y">3</domain:period><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>anna</domain:registrant><domain:admin>TESTER</domain:admin><domain:authInfo>heslo</domain:authInfo></domain:create></create><clTRID>djmf002#13-06-14at15:32:01</clTRID></command></epp>\n	f
244	2013-06-14 13:32:01.387742	3	f	122	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>ginger04.cz</domain:name><domain:crDate>2013-06-14T15:32:01+02:00</domain:crDate><domain:exDate>2016-06-14</domain:exDate></domain:creData></resData><trID><clTRID>djmf002#13-06-14at15:32:01</clTRID><svTRID>ReqID-0000000122</svTRID></trID></response></epp>\n	t
245	2013-06-14 13:32:01.509354	3	f	123	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>djmf003#13-06-14at15:32:01</clTRID></command></epp>\n	f
246	2013-06-14 13:32:01.509354	3	f	123	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>djmf003#13-06-14at15:32:01</clTRID><svTRID>ReqID-0000000123</svTRID></trID></response></epp>\n	t
247	2013-06-14 13:32:01.638268	3	f	124	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>dccy001#13-06-14at15:32:01</clTRID></command></epp>\n	f
248	2013-06-14 13:32:01.638268	3	f	124	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>dccy001#13-06-14at15:32:01</clTRID><svTRID>ReqID-0000000124</svTRID></trID></response></epp>\n	t
249	2013-06-14 13:32:01.69753	3	f	125	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>ginger05.cz</domain:name><domain:period unit="y">3</domain:period><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>anna</domain:registrant><domain:admin>TESTER</domain:admin><domain:authInfo>heslo</domain:authInfo></domain:create></create><clTRID>dccy002#13-06-14at15:32:01</clTRID></command></epp>\n	f
250	2013-06-14 13:32:01.69753	3	f	125	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>ginger05.cz</domain:name><domain:crDate>2013-06-14T15:32:01+02:00</domain:crDate><domain:exDate>2016-06-14</domain:exDate></domain:creData></resData><trID><clTRID>dccy002#13-06-14at15:32:01</clTRID><svTRID>ReqID-0000000125</svTRID></trID></response></epp>\n	t
251	2013-06-14 13:32:01.819018	3	f	126	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>dccy003#13-06-14at15:32:01</clTRID></command></epp>\n	f
252	2013-06-14 13:32:01.819018	3	f	126	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>dccy003#13-06-14at15:32:01</clTRID><svTRID>ReqID-0000000126</svTRID></trID></response></epp>\n	t
253	2013-06-14 13:32:01.958009	3	f	127	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>cwdf001#13-06-14at15:32:01</clTRID></command></epp>\n	f
254	2013-06-14 13:32:01.958009	3	f	127	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>cwdf001#13-06-14at15:32:01</clTRID><svTRID>ReqID-0000000127</svTRID></trID></response></epp>\n	t
255	2013-06-14 13:32:02.01731	3	f	128	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>ginger06.cz</domain:name><domain:period unit="y">3</domain:period><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>anna</domain:registrant><domain:admin>TESTER</domain:admin><domain:authInfo>heslo</domain:authInfo></domain:create></create><clTRID>cwdf002#13-06-14at15:32:02</clTRID></command></epp>\n	f
256	2013-06-14 13:32:02.01731	3	f	128	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>ginger06.cz</domain:name><domain:crDate>2013-06-14T15:32:02+02:00</domain:crDate><domain:exDate>2016-06-14</domain:exDate></domain:creData></resData><trID><clTRID>cwdf002#13-06-14at15:32:02</clTRID><svTRID>ReqID-0000000128</svTRID></trID></response></epp>\n	t
257	2013-06-14 13:32:02.140865	3	f	129	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>cwdf003#13-06-14at15:32:02</clTRID></command></epp>\n	f
258	2013-06-14 13:32:02.140865	3	f	129	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>cwdf003#13-06-14at15:32:02</clTRID><svTRID>ReqID-0000000129</svTRID></trID></response></epp>\n	t
259	2013-06-14 13:32:02.260969	3	f	130	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>gzpq001#13-06-14at15:32:02</clTRID></command></epp>\n	f
260	2013-06-14 13:32:02.260969	3	f	130	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>gzpq001#13-06-14at15:32:02</clTRID><svTRID>ReqID-0000000130</svTRID></trID></response></epp>\n	t
261	2013-06-14 13:32:02.321543	3	f	131	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>ginger07.cz</domain:name><domain:period unit="y">3</domain:period><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>anna</domain:registrant><domain:admin>TESTER</domain:admin><domain:authInfo>heslo</domain:authInfo></domain:create></create><clTRID>gzpq002#13-06-14at15:32:02</clTRID></command></epp>\n	f
262	2013-06-14 13:32:02.321543	3	f	131	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>ginger07.cz</domain:name><domain:crDate>2013-06-14T15:32:02+02:00</domain:crDate><domain:exDate>2016-06-14</domain:exDate></domain:creData></resData><trID><clTRID>gzpq002#13-06-14at15:32:02</clTRID><svTRID>ReqID-0000000131</svTRID></trID></response></epp>\n	t
263	2013-06-14 13:32:02.442676	3	f	132	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>gzpq003#13-06-14at15:32:02</clTRID></command></epp>\n	f
264	2013-06-14 13:32:02.442676	3	f	132	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>gzpq003#13-06-14at15:32:02</clTRID><svTRID>ReqID-0000000132</svTRID></trID></response></epp>\n	t
265	2013-06-14 13:32:02.566777	3	f	133	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>cepx001#13-06-14at15:32:02</clTRID></command></epp>\n	f
266	2013-06-14 13:32:02.566777	3	f	133	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>cepx001#13-06-14at15:32:02</clTRID><svTRID>ReqID-0000000133</svTRID></trID></response></epp>\n	t
267	2013-06-14 13:32:02.626066	3	f	134	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>ginger08.cz</domain:name><domain:period unit="y">3</domain:period><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>anna</domain:registrant><domain:admin>TESTER</domain:admin><domain:authInfo>heslo</domain:authInfo></domain:create></create><clTRID>cepx002#13-06-14at15:32:02</clTRID></command></epp>\n	f
268	2013-06-14 13:32:02.626066	3	f	134	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>ginger08.cz</domain:name><domain:crDate>2013-06-14T15:32:02+02:00</domain:crDate><domain:exDate>2016-06-14</domain:exDate></domain:creData></resData><trID><clTRID>cepx002#13-06-14at15:32:02</clTRID><svTRID>ReqID-0000000134</svTRID></trID></response></epp>\n	t
269	2013-06-14 13:32:02.747333	3	f	135	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>cepx003#13-06-14at15:32:02</clTRID></command></epp>\n	f
270	2013-06-14 13:32:02.747333	3	f	135	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>cepx003#13-06-14at15:32:02</clTRID><svTRID>ReqID-0000000135</svTRID></trID></response></epp>\n	t
271	2013-06-14 13:32:02.868341	3	f	136	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>zcru001#13-06-14at15:32:02</clTRID></command></epp>\n	f
272	2013-06-14 13:32:02.868341	3	f	136	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>zcru001#13-06-14at15:32:02</clTRID><svTRID>ReqID-0000000136</svTRID></trID></response></epp>\n	t
273	2013-06-14 13:32:02.928105	3	f	137	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>ginger09.cz</domain:name><domain:period unit="y">3</domain:period><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>anna</domain:registrant><domain:admin>TESTER</domain:admin><domain:authInfo>heslo</domain:authInfo></domain:create></create><clTRID>zcru002#13-06-14at15:32:02</clTRID></command></epp>\n	f
274	2013-06-14 13:32:02.928105	3	f	137	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>ginger09.cz</domain:name><domain:crDate>2013-06-14T15:32:02+02:00</domain:crDate><domain:exDate>2016-06-14</domain:exDate></domain:creData></resData><trID><clTRID>zcru002#13-06-14at15:32:02</clTRID><svTRID>ReqID-0000000137</svTRID></trID></response></epp>\n	t
275	2013-06-14 13:32:03.050358	3	f	138	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>zcru003#13-06-14at15:32:03</clTRID></command></epp>\n	f
276	2013-06-14 13:32:03.050358	3	f	138	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>zcru003#13-06-14at15:32:03</clTRID><svTRID>ReqID-0000000138</svTRID></trID></response></epp>\n	t
277	2013-06-14 13:32:03.164551	3	f	139	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>rpro001#13-06-14at15:32:03</clTRID></command></epp>\n	f
278	2013-06-14 13:32:03.164551	3	f	139	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>rpro001#13-06-14at15:32:03</clTRID><svTRID>ReqID-0000000139</svTRID></trID></response></epp>\n	t
279	2013-06-14 13:32:03.223592	3	f	140	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>ginger10.cz</domain:name><domain:period unit="y">3</domain:period><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>anna</domain:registrant><domain:admin>TESTER</domain:admin><domain:authInfo>heslo</domain:authInfo></domain:create></create><clTRID>rpro002#13-06-14at15:32:03</clTRID></command></epp>\n	f
280	2013-06-14 13:32:03.223592	3	f	140	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>ginger10.cz</domain:name><domain:crDate>2013-06-14T15:32:03+02:00</domain:crDate><domain:exDate>2016-06-14</domain:exDate></domain:creData></resData><trID><clTRID>rpro002#13-06-14at15:32:03</clTRID><svTRID>ReqID-0000000140</svTRID></trID></response></epp>\n	t
281	2013-06-14 13:32:03.344442	3	f	141	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>rpro003#13-06-14at15:32:03</clTRID></command></epp>\n	f
282	2013-06-14 13:32:03.344442	3	f	141	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>rpro003#13-06-14at15:32:03</clTRID><svTRID>ReqID-0000000141</svTRID></trID></response></epp>\n	t
283	2013-06-14 13:32:03.470343	3	f	142	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>ysvi001#13-06-14at15:32:03</clTRID></command></epp>\n	f
284	2013-06-14 13:32:03.470343	3	f	142	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>ysvi001#13-06-14at15:32:03</clTRID><svTRID>ReqID-0000000142</svTRID></trID></response></epp>\n	t
285	2013-06-14 13:32:03.529912	3	f	143	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>1.1.1.8.4.5.2.2.2.0.2.4.e164.arpa</domain:name><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>TESTER</domain:registrant><domain:admin>anna</domain:admin><domain:admin>bob</domain:admin></domain:create></create><extension><enumval:create xmlns:enumval="http://www.nic.cz/xml/epp/enumval-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/enumval-1.2 enumval-1.2.xsd"><enumval:valExDate>2013-11-14</enumval:valExDate></enumval:create></extension><clTRID>ysvi002#13-06-14at15:32:03</clTRID></command></epp>\n	f
286	2013-06-14 13:32:03.529912	3	f	143	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>1.1.1.8.4.5.2.2.2.0.2.4.e164.arpa</domain:name><domain:crDate>2013-06-14T15:32:03+02:00</domain:crDate><domain:exDate>2014-06-14</domain:exDate></domain:creData></resData><trID><clTRID>ysvi002#13-06-14at15:32:03</clTRID><svTRID>ReqID-0000000143</svTRID></trID></response></epp>\n	t
287	2013-06-14 13:32:03.659433	3	f	144	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>ysvi003#13-06-14at15:32:03</clTRID></command></epp>\n	f
288	2013-06-14 13:32:03.659433	3	f	144	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>ysvi003#13-06-14at15:32:03</clTRID><svTRID>ReqID-0000000144</svTRID></trID></response></epp>\n	t
289	2013-06-14 13:32:03.78648	3	f	145	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>xerk001#13-06-14at15:32:03</clTRID></command></epp>\n	f
290	2013-06-14 13:32:03.78648	3	f	145	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>xerk001#13-06-14at15:32:03</clTRID><svTRID>ReqID-0000000145</svTRID></trID></response></epp>\n	t
291	2013-06-14 13:32:03.845724	3	f	146	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>2.1.1.8.4.5.2.2.2.0.2.4.e164.arpa</domain:name><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>TESTER</domain:registrant><domain:admin>anna</domain:admin><domain:admin>bob</domain:admin></domain:create></create><extension><enumval:create xmlns:enumval="http://www.nic.cz/xml/epp/enumval-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/enumval-1.2 enumval-1.2.xsd"><enumval:valExDate>2013-11-14</enumval:valExDate></enumval:create></extension><clTRID>xerk002#13-06-14at15:32:03</clTRID></command></epp>\n	f
292	2013-06-14 13:32:03.845724	3	f	146	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>2.1.1.8.4.5.2.2.2.0.2.4.e164.arpa</domain:name><domain:crDate>2013-06-14T15:32:03+02:00</domain:crDate><domain:exDate>2014-06-14</domain:exDate></domain:creData></resData><trID><clTRID>xerk002#13-06-14at15:32:03</clTRID><svTRID>ReqID-0000000146</svTRID></trID></response></epp>\n	t
293	2013-06-14 13:32:03.975974	3	f	147	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>xerk003#13-06-14at15:32:03</clTRID></command></epp>\n	f
294	2013-06-14 13:32:03.975974	3	f	147	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>xerk003#13-06-14at15:32:03</clTRID><svTRID>ReqID-0000000147</svTRID></trID></response></epp>\n	t
295	2013-06-14 13:32:04.106177	3	f	148	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>dxrl001#13-06-14at15:32:04</clTRID></command></epp>\n	f
296	2013-06-14 13:32:04.106177	3	f	148	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>dxrl001#13-06-14at15:32:04</clTRID><svTRID>ReqID-0000000148</svTRID></trID></response></epp>\n	t
297	2013-06-14 13:32:04.16571	3	f	149	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>3.1.1.8.4.5.2.2.2.0.2.4.e164.arpa</domain:name><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>TESTER</domain:registrant><domain:admin>anna</domain:admin><domain:admin>bob</domain:admin></domain:create></create><extension><enumval:create xmlns:enumval="http://www.nic.cz/xml/epp/enumval-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/enumval-1.2 enumval-1.2.xsd"><enumval:valExDate>2013-11-14</enumval:valExDate></enumval:create></extension><clTRID>dxrl002#13-06-14at15:32:04</clTRID></command></epp>\n	f
298	2013-06-14 13:32:04.16571	3	f	149	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>3.1.1.8.4.5.2.2.2.0.2.4.e164.arpa</domain:name><domain:crDate>2013-06-14T15:32:04+02:00</domain:crDate><domain:exDate>2014-06-14</domain:exDate></domain:creData></resData><trID><clTRID>dxrl002#13-06-14at15:32:04</clTRID><svTRID>ReqID-0000000149</svTRID></trID></response></epp>\n	t
299	2013-06-14 13:32:04.293804	3	f	150	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>dxrl003#13-06-14at15:32:04</clTRID></command></epp>\n	f
300	2013-06-14 13:32:04.293804	3	f	150	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>dxrl003#13-06-14at15:32:04</clTRID><svTRID>ReqID-0000000150</svTRID></trID></response></epp>\n	t
301	2013-06-14 13:32:04.424238	3	f	151	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>vppb001#13-06-14at15:32:04</clTRID></command></epp>\n	f
302	2013-06-14 13:32:04.424238	3	f	151	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>vppb001#13-06-14at15:32:04</clTRID><svTRID>ReqID-0000000151</svTRID></trID></response></epp>\n	t
303	2013-06-14 13:32:04.483171	3	f	152	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>4.1.1.8.4.5.2.2.2.0.2.4.e164.arpa</domain:name><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>TESTER</domain:registrant><domain:admin>anna</domain:admin><domain:admin>bob</domain:admin></domain:create></create><extension><enumval:create xmlns:enumval="http://www.nic.cz/xml/epp/enumval-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/enumval-1.2 enumval-1.2.xsd"><enumval:valExDate>2013-11-14</enumval:valExDate></enumval:create></extension><clTRID>vppb002#13-06-14at15:32:04</clTRID></command></epp>\n	f
304	2013-06-14 13:32:04.483171	3	f	152	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>4.1.1.8.4.5.2.2.2.0.2.4.e164.arpa</domain:name><domain:crDate>2013-06-14T15:32:04+02:00</domain:crDate><domain:exDate>2014-06-14</domain:exDate></domain:creData></resData><trID><clTRID>vppb002#13-06-14at15:32:04</clTRID><svTRID>ReqID-0000000152</svTRID></trID></response></epp>\n	t
305	2013-06-14 13:32:04.610724	3	f	153	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>vppb003#13-06-14at15:32:04</clTRID></command></epp>\n	f
306	2013-06-14 13:32:04.610724	3	f	153	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>vppb003#13-06-14at15:32:04</clTRID><svTRID>ReqID-0000000153</svTRID></trID></response></epp>\n	t
307	2013-06-14 13:32:04.740122	3	f	154	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>llna001#13-06-14at15:32:04</clTRID></command></epp>\n	f
308	2013-06-14 13:32:04.740122	3	f	154	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>llna001#13-06-14at15:32:04</clTRID><svTRID>ReqID-0000000154</svTRID></trID></response></epp>\n	t
309	2013-06-14 13:32:04.799478	3	f	155	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>5.1.1.8.4.5.2.2.2.0.2.4.e164.arpa</domain:name><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>TESTER</domain:registrant><domain:admin>anna</domain:admin><domain:admin>bob</domain:admin></domain:create></create><extension><enumval:create xmlns:enumval="http://www.nic.cz/xml/epp/enumval-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/enumval-1.2 enumval-1.2.xsd"><enumval:valExDate>2013-11-14</enumval:valExDate></enumval:create></extension><clTRID>llna002#13-06-14at15:32:04</clTRID></command></epp>\n	f
310	2013-06-14 13:32:04.799478	3	f	155	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>5.1.1.8.4.5.2.2.2.0.2.4.e164.arpa</domain:name><domain:crDate>2013-06-14T15:32:04+02:00</domain:crDate><domain:exDate>2014-06-14</domain:exDate></domain:creData></resData><trID><clTRID>llna002#13-06-14at15:32:04</clTRID><svTRID>ReqID-0000000155</svTRID></trID></response></epp>\n	t
311	2013-06-14 13:32:04.928523	3	f	156	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>llna003#13-06-14at15:32:04</clTRID></command></epp>\n	f
312	2013-06-14 13:32:04.928523	3	f	156	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>llna003#13-06-14at15:32:04</clTRID><svTRID>ReqID-0000000156</svTRID></trID></response></epp>\n	t
313	2013-06-14 13:32:05.057386	3	f	157	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>yovx001#13-06-14at15:32:05</clTRID></command></epp>\n	f
314	2013-06-14 13:32:05.057386	3	f	157	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>yovx001#13-06-14at15:32:05</clTRID><svTRID>ReqID-0000000157</svTRID></trID></response></epp>\n	t
315	2013-06-14 13:32:05.117046	3	f	158	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>6.1.1.8.4.5.2.2.2.0.2.4.e164.arpa</domain:name><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>TESTER</domain:registrant><domain:admin>anna</domain:admin><domain:admin>bob</domain:admin></domain:create></create><extension><enumval:create xmlns:enumval="http://www.nic.cz/xml/epp/enumval-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/enumval-1.2 enumval-1.2.xsd"><enumval:valExDate>2013-11-14</enumval:valExDate></enumval:create></extension><clTRID>yovx002#13-06-14at15:32:05</clTRID></command></epp>\n	f
316	2013-06-14 13:32:05.117046	3	f	158	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>6.1.1.8.4.5.2.2.2.0.2.4.e164.arpa</domain:name><domain:crDate>2013-06-14T15:32:05+02:00</domain:crDate><domain:exDate>2014-06-14</domain:exDate></domain:creData></resData><trID><clTRID>yovx002#13-06-14at15:32:05</clTRID><svTRID>ReqID-0000000158</svTRID></trID></response></epp>\n	t
317	2013-06-14 13:32:05.245854	3	f	159	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>yovx003#13-06-14at15:32:05</clTRID></command></epp>\n	f
318	2013-06-14 13:32:05.245854	3	f	159	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>yovx003#13-06-14at15:32:05</clTRID><svTRID>ReqID-0000000159</svTRID></trID></response></epp>\n	t
319	2013-06-14 13:32:05.37904	3	f	160	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>tzzp001#13-06-14at15:32:05</clTRID></command></epp>\n	f
320	2013-06-14 13:32:05.37904	3	f	160	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>tzzp001#13-06-14at15:32:05</clTRID><svTRID>ReqID-0000000160</svTRID></trID></response></epp>\n	t
321	2013-06-14 13:32:05.438573	3	f	161	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>7.1.1.8.4.5.2.2.2.0.2.4.e164.arpa</domain:name><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>TESTER</domain:registrant><domain:admin>anna</domain:admin><domain:admin>bob</domain:admin></domain:create></create><extension><enumval:create xmlns:enumval="http://www.nic.cz/xml/epp/enumval-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/enumval-1.2 enumval-1.2.xsd"><enumval:valExDate>2013-11-14</enumval:valExDate></enumval:create></extension><clTRID>tzzp002#13-06-14at15:32:05</clTRID></command></epp>\n	f
322	2013-06-14 13:32:05.438573	3	f	161	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>7.1.1.8.4.5.2.2.2.0.2.4.e164.arpa</domain:name><domain:crDate>2013-06-14T15:32:05+02:00</domain:crDate><domain:exDate>2014-06-14</domain:exDate></domain:creData></resData><trID><clTRID>tzzp002#13-06-14at15:32:05</clTRID><svTRID>ReqID-0000000161</svTRID></trID></response></epp>\n	t
323	2013-06-14 13:32:05.567124	3	f	162	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>tzzp003#13-06-14at15:32:05</clTRID></command></epp>\n	f
324	2013-06-14 13:32:05.567124	3	f	162	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>tzzp003#13-06-14at15:32:05</clTRID><svTRID>ReqID-0000000162</svTRID></trID></response></epp>\n	t
325	2013-06-14 13:32:05.69046	3	f	163	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>kwfg001#13-06-14at15:32:05</clTRID></command></epp>\n	f
326	2013-06-14 13:32:05.69046	3	f	163	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>kwfg001#13-06-14at15:32:05</clTRID><svTRID>ReqID-0000000163</svTRID></trID></response></epp>\n	t
327	2013-06-14 13:32:05.747844	3	f	164	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>8.1.1.8.4.5.2.2.2.0.2.4.e164.arpa</domain:name><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>TESTER</domain:registrant><domain:admin>anna</domain:admin><domain:admin>bob</domain:admin></domain:create></create><extension><enumval:create xmlns:enumval="http://www.nic.cz/xml/epp/enumval-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/enumval-1.2 enumval-1.2.xsd"><enumval:valExDate>2013-11-14</enumval:valExDate></enumval:create></extension><clTRID>kwfg002#13-06-14at15:32:05</clTRID></command></epp>\n	f
328	2013-06-14 13:32:05.747844	3	f	164	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>8.1.1.8.4.5.2.2.2.0.2.4.e164.arpa</domain:name><domain:crDate>2013-06-14T15:32:05+02:00</domain:crDate><domain:exDate>2014-06-14</domain:exDate></domain:creData></resData><trID><clTRID>kwfg002#13-06-14at15:32:05</clTRID><svTRID>ReqID-0000000164</svTRID></trID></response></epp>\n	t
329	2013-06-14 13:32:05.875628	3	f	165	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>kwfg003#13-06-14at15:32:05</clTRID></command></epp>\n	f
330	2013-06-14 13:32:05.875628	3	f	165	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>kwfg003#13-06-14at15:32:05</clTRID><svTRID>ReqID-0000000165</svTRID></trID></response></epp>\n	t
331	2013-06-14 13:32:05.998781	3	f	166	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>qxcq001#13-06-14at15:32:05</clTRID></command></epp>\n	f
332	2013-06-14 13:32:05.998781	3	f	166	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>qxcq001#13-06-14at15:32:05</clTRID><svTRID>ReqID-0000000166</svTRID></trID></response></epp>\n	t
333	2013-06-14 13:32:06.058387	3	f	167	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>9.1.1.8.4.5.2.2.2.0.2.4.e164.arpa</domain:name><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>TESTER</domain:registrant><domain:admin>anna</domain:admin><domain:admin>bob</domain:admin></domain:create></create><extension><enumval:create xmlns:enumval="http://www.nic.cz/xml/epp/enumval-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/enumval-1.2 enumval-1.2.xsd"><enumval:valExDate>2013-11-14</enumval:valExDate></enumval:create></extension><clTRID>qxcq002#13-06-14at15:32:06</clTRID></command></epp>\n	f
334	2013-06-14 13:32:06.058387	3	f	167	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>9.1.1.8.4.5.2.2.2.0.2.4.e164.arpa</domain:name><domain:crDate>2013-06-14T15:32:06+02:00</domain:crDate><domain:exDate>2014-06-14</domain:exDate></domain:creData></resData><trID><clTRID>qxcq002#13-06-14at15:32:06</clTRID><svTRID>ReqID-0000000167</svTRID></trID></response></epp>\n	t
335	2013-06-14 13:32:06.186072	3	f	168	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>qxcq003#13-06-14at15:32:06</clTRID></command></epp>\n	f
336	2013-06-14 13:32:06.186072	3	f	168	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>qxcq003#13-06-14at15:32:06</clTRID><svTRID>ReqID-0000000168</svTRID></trID></response></epp>\n	t
337	2013-06-14 13:32:06.308321	3	f	169	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>qwua001#13-06-14at15:32:06</clTRID></command></epp>\n	f
338	2013-06-14 13:32:06.308321	3	f	169	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>qwua001#13-06-14at15:32:06</clTRID><svTRID>ReqID-0000000169</svTRID></trID></response></epp>\n	t
339	2013-06-14 13:32:06.36519	3	f	170	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>0.2.1.8.4.5.2.2.2.0.2.4.e164.arpa</domain:name><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>TESTER</domain:registrant><domain:admin>anna</domain:admin><domain:admin>bob</domain:admin></domain:create></create><extension><enumval:create xmlns:enumval="http://www.nic.cz/xml/epp/enumval-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/enumval-1.2 enumval-1.2.xsd"><enumval:valExDate>2013-11-14</enumval:valExDate></enumval:create></extension><clTRID>qwua002#13-06-14at15:32:06</clTRID></command></epp>\n	f
340	2013-06-14 13:32:06.36519	3	f	170	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>0.2.1.8.4.5.2.2.2.0.2.4.e164.arpa</domain:name><domain:crDate>2013-06-14T15:32:06+02:00</domain:crDate><domain:exDate>2014-06-14</domain:exDate></domain:creData></resData><trID><clTRID>qwua002#13-06-14at15:32:06</clTRID><svTRID>ReqID-0000000170</svTRID></trID></response></epp>\n	t
341	2013-06-14 13:32:06.493315	3	f	171	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>qwua003#13-06-14at15:32:06</clTRID></command></epp>\n	f
342	2013-06-14 13:32:06.493315	3	f	171	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>qwua003#13-06-14at15:32:06</clTRID><svTRID>ReqID-0000000171</svTRID></trID></response></epp>\n	t
343	2013-06-14 13:32:06.617628	3	f	172	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><login><clID>REG-FRED_A</clID><pw>passwd</pw><options><version>1.0</version><lang>en</lang></options><svcs><objURI>http://www.nic.cz/xml/epp/contact-1.6</objURI><objURI>http://www.nic.cz/xml/epp/nsset-1.2</objURI><objURI>http://www.nic.cz/xml/epp/domain-1.4</objURI><objURI>http://www.nic.cz/xml/epp/keyset-1.3</objURI><svcExtension><extURI>http://www.nic.cz/xml/epp/enumval-1.2</extURI></svcExtension></svcs></login><clTRID>klhr001#13-06-14at15:32:06</clTRID></command></epp>\n	f
344	2013-06-14 13:32:06.617628	3	f	172	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><trID><clTRID>klhr001#13-06-14at15:32:06</clTRID><svTRID>ReqID-0000000172</svTRID></trID></response></epp>\n	t
345	2013-06-14 13:32:06.676859	3	f	173	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.xsd"><domain:name>1.2.1.8.4.5.2.2.2.0.2.4.e164.arpa</domain:name><domain:nsset>nssid01</domain:nsset><domain:keyset>keyid01</domain:keyset><domain:registrant>TESTER</domain:registrant><domain:admin>anna</domain:admin><domain:admin>bob</domain:admin></domain:create></create><extension><enumval:create xmlns:enumval="http://www.nic.cz/xml/epp/enumval-1.2" xsi:schemaLocation="http://www.nic.cz/xml/epp/enumval-1.2 enumval-1.2.xsd"><enumval:valExDate>2013-11-14</enumval:valExDate></enumval:create></extension><clTRID>klhr002#13-06-14at15:32:06</clTRID></command></epp>\n	f
346	2013-06-14 13:32:06.676859	3	f	173	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1000"><msg>Command completed successfully</msg></result><resData><domain:creData xmlns:domain="http://www.nic.cz/xml/epp/domain-1.4" xsi:schemaLocation="http://www.nic.cz/xml/epp/domain-1.4 domain-1.4.1.xsd"><domain:name>1.2.1.8.4.5.2.2.2.0.2.4.e164.arpa</domain:name><domain:crDate>2013-06-14T15:32:06+02:00</domain:crDate><domain:exDate>2014-06-14</domain:exDate></domain:creData></resData><trID><clTRID>klhr002#13-06-14at15:32:06</clTRID><svTRID>ReqID-0000000173</svTRID></trID></response></epp>\n	t
347	2013-06-14 13:32:06.805535	3	f	174	<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><logout/><clTRID>klhr003#13-06-14at15:32:06</clTRID></command></epp>\n	f
348	2013-06-14 13:32:06.805535	3	f	174	<?xml version="1.0" encoding="UTF-8"?>\n<epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><response><result code="1500"><msg>Command completed successfully; ending session</msg></result><trID><clTRID>klhr003#13-06-14at15:32:06</clTRID><svTRID>ReqID-0000000174</svTRID></trID></response></epp>\n	t
\.


--
-- Data for Name: request_epp_13_06; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY request_epp_13_06 (id, time_begin, time_end, source_ip, service_id, request_type_id, session_id, user_name, is_monitoring, result_code_id, user_id) FROM stdin;
1	2013-06-14 13:31:49.377405	2013-06-14 13:31:49.434019	127.0.0.1	3	100	1	REG-FRED_A	f	9	\N
2	2013-06-14 13:31:49.459803	2013-06-14 13:31:49.55564	127.0.0.1	3	204	1	REG-FRED_A	f	9	\N
3	2013-06-14 13:31:49.578717	2013-06-14 13:31:49.602711	127.0.0.1	3	101	1	REG-FRED_A	f	13	\N
4	2013-06-14 13:31:49.696274	2013-06-14 13:31:49.731304	127.0.0.1	3	100	2	REG-FRED_A	f	9	\N
5	2013-06-14 13:31:49.756596	2013-06-14 13:31:49.845238	127.0.0.1	3	204	2	REG-FRED_A	f	9	\N
6	2013-06-14 13:31:49.867874	2013-06-14 13:31:49.891737	127.0.0.1	3	101	2	REG-FRED_A	f	13	\N
7	2013-06-14 13:31:49.990702	2013-06-14 13:31:50.025369	127.0.0.1	3	100	3	REG-FRED_A	f	9	\N
8	2013-06-14 13:31:50.051062	2013-06-14 13:31:50.139826	127.0.0.1	3	204	3	REG-FRED_A	f	9	\N
9	2013-06-14 13:31:50.163623	2013-06-14 13:31:50.187833	127.0.0.1	3	101	3	REG-FRED_A	f	13	\N
10	2013-06-14 13:31:50.28923	2013-06-14 13:31:50.324153	127.0.0.1	3	100	4	REG-FRED_A	f	9	\N
11	2013-06-14 13:31:50.349693	2013-06-14 13:31:50.43697	127.0.0.1	3	204	4	REG-FRED_A	f	9	\N
12	2013-06-14 13:31:50.459946	2013-06-14 13:31:50.484105	127.0.0.1	3	101	4	REG-FRED_A	f	13	\N
13	2013-06-14 13:31:50.589583	2013-06-14 13:31:50.624715	127.0.0.1	3	100	5	REG-FRED_A	f	9	\N
14	2013-06-14 13:31:50.651337	2013-06-14 13:31:50.739266	127.0.0.1	3	204	5	REG-FRED_A	f	9	\N
15	2013-06-14 13:31:50.762072	2013-06-14 13:31:50.785848	127.0.0.1	3	101	5	REG-FRED_A	f	13	\N
16	2013-06-14 13:31:50.884535	2013-06-14 13:31:50.919122	127.0.0.1	3	100	6	REG-FRED_A	f	9	\N
17	2013-06-14 13:31:50.944806	2013-06-14 13:31:51.032297	127.0.0.1	3	204	6	REG-FRED_A	f	9	\N
18	2013-06-14 13:31:51.059879	2013-06-14 13:31:51.083951	127.0.0.1	3	101	6	REG-FRED_A	f	13	\N
19	2013-06-14 13:31:51.189496	2013-06-14 13:31:51.224454	127.0.0.1	3	100	7	REG-FRED_A	f	9	\N
20	2013-06-14 13:31:51.250398	2013-06-14 13:31:51.338531	127.0.0.1	3	204	7	REG-FRED_A	f	9	\N
21	2013-06-14 13:31:51.361512	2013-06-14 13:31:51.385453	127.0.0.1	3	101	7	REG-FRED_A	f	13	\N
22	2013-06-14 13:31:51.613755	2013-06-14 13:31:51.648564	127.0.0.1	3	100	8	REG-FRED_A	f	9	\N
23	2013-06-14 13:31:51.672815	2013-06-14 13:31:51.762961	127.0.0.1	3	404	8	REG-FRED_A	f	9	\N
24	2013-06-14 13:31:51.785499	2013-06-14 13:31:51.809746	127.0.0.1	3	101	8	REG-FRED_A	f	13	\N
25	2013-06-14 13:31:51.902495	2013-06-14 13:31:51.937059	127.0.0.1	3	100	9	REG-FRED_A	f	9	\N
26	2013-06-14 13:31:51.961345	2013-06-14 13:31:52.047442	127.0.0.1	3	404	9	REG-FRED_A	f	9	\N
27	2013-06-14 13:31:52.070041	2013-06-14 13:31:52.093912	127.0.0.1	3	101	9	REG-FRED_A	f	13	\N
28	2013-06-14 13:31:52.19672	2013-06-14 13:31:52.231805	127.0.0.1	3	100	10	REG-FRED_A	f	9	\N
29	2013-06-14 13:31:52.25608	2013-06-14 13:31:52.343207	127.0.0.1	3	404	10	REG-FRED_A	f	9	\N
30	2013-06-14 13:31:52.365794	2013-06-14 13:31:52.389734	127.0.0.1	3	101	10	REG-FRED_A	f	13	\N
31	2013-06-14 13:31:52.487891	2013-06-14 13:31:52.523141	127.0.0.1	3	100	11	REG-FRED_A	f	9	\N
32	2013-06-14 13:31:52.547287	2013-06-14 13:31:52.615275	127.0.0.1	3	404	11	REG-FRED_A	f	9	\N
33	2013-06-14 13:31:52.638	2013-06-14 13:31:52.66226	127.0.0.1	3	101	11	REG-FRED_A	f	13	\N
34	2013-06-14 13:31:52.769179	2013-06-14 13:31:52.803797	127.0.0.1	3	100	12	REG-FRED_A	f	9	\N
35	2013-06-14 13:31:52.827942	2013-06-14 13:31:52.917758	127.0.0.1	3	404	12	REG-FRED_A	f	9	\N
36	2013-06-14 13:31:52.940235	2013-06-14 13:31:52.963896	127.0.0.1	3	101	12	REG-FRED_A	f	13	\N
37	2013-06-14 13:31:53.060071	2013-06-14 13:31:53.094863	127.0.0.1	3	100	13	REG-FRED_A	f	9	\N
38	2013-06-14 13:31:53.119983	2013-06-14 13:31:53.206579	127.0.0.1	3	404	13	REG-FRED_A	f	9	\N
39	2013-06-14 13:31:53.229053	2013-06-14 13:31:53.252901	127.0.0.1	3	101	13	REG-FRED_A	f	13	\N
40	2013-06-14 13:31:53.356298	2013-06-14 13:31:53.391277	127.0.0.1	3	100	14	REG-FRED_A	f	9	\N
41	2013-06-14 13:31:53.415641	2013-06-14 13:31:53.502479	127.0.0.1	3	404	14	REG-FRED_A	f	9	\N
42	2013-06-14 13:31:53.525063	2013-06-14 13:31:53.54905	127.0.0.1	3	101	14	REG-FRED_A	f	13	\N
43	2013-06-14 13:31:53.650397	2013-06-14 13:31:53.685202	127.0.0.1	3	100	15	REG-FRED_A	f	9	\N
44	2013-06-14 13:31:53.70983	2013-06-14 13:31:53.796229	127.0.0.1	3	404	15	REG-FRED_A	f	9	\N
45	2013-06-14 13:31:53.818889	2013-06-14 13:31:53.843036	127.0.0.1	3	101	15	REG-FRED_A	f	13	\N
46	2013-06-14 13:31:53.948367	2013-06-14 13:31:53.982746	127.0.0.1	3	100	16	REG-FRED_A	f	9	\N
47	2013-06-14 13:31:54.007041	2013-06-14 13:31:54.093886	127.0.0.1	3	404	16	REG-FRED_A	f	9	\N
48	2013-06-14 13:31:54.116438	2013-06-14 13:31:54.140276	127.0.0.1	3	101	16	REG-FRED_A	f	13	\N
49	2013-06-14 13:31:54.235866	2013-06-14 13:31:54.270894	127.0.0.1	3	100	17	REG-FRED_A	f	9	\N
50	2013-06-14 13:31:54.296205	2013-06-14 13:31:54.382514	127.0.0.1	3	404	17	REG-FRED_A	f	9	\N
51	2013-06-14 13:31:54.405267	2013-06-14 13:31:54.429077	127.0.0.1	3	101	17	REG-FRED_A	f	13	\N
52	2013-06-14 13:31:54.533374	2013-06-14 13:31:54.567739	127.0.0.1	3	100	18	REG-FRED_A	f	9	\N
53	2013-06-14 13:31:54.591899	2013-06-14 13:31:54.66606	127.0.0.1	3	604	18	REG-FRED_A	f	9	\N
54	2013-06-14 13:31:54.688549	2013-06-14 13:31:54.712606	127.0.0.1	3	101	18	REG-FRED_A	f	13	\N
55	2013-06-14 13:31:54.817635	2013-06-14 13:31:54.85266	127.0.0.1	3	100	19	REG-FRED_A	f	9	\N
56	2013-06-14 13:31:54.875497	2013-06-14 13:31:54.927562	127.0.0.1	3	604	19	REG-FRED_A	f	9	\N
57	2013-06-14 13:31:54.950894	2013-06-14 13:31:54.975469	127.0.0.1	3	101	19	REG-FRED_A	f	13	\N
58	2013-06-14 13:31:55.076237	2013-06-14 13:31:55.111227	127.0.0.1	3	100	20	REG-FRED_A	f	9	\N
59	2013-06-14 13:31:55.135419	2013-06-14 13:31:55.208471	127.0.0.1	3	604	20	REG-FRED_A	f	9	\N
60	2013-06-14 13:31:55.23132	2013-06-14 13:31:55.255372	127.0.0.1	3	101	20	REG-FRED_A	f	13	\N
61	2013-06-14 13:31:55.352745	2013-06-14 13:31:55.388552	127.0.0.1	3	100	21	REG-FRED_A	f	9	\N
62	2013-06-14 13:31:55.413411	2013-06-14 13:31:55.486575	127.0.0.1	3	604	21	REG-FRED_A	f	9	\N
63	2013-06-14 13:31:55.509039	2013-06-14 13:31:55.532761	127.0.0.1	3	101	21	REG-FRED_A	f	13	\N
64	2013-06-14 13:31:55.637527	2013-06-14 13:31:55.672495	127.0.0.1	3	100	22	REG-FRED_A	f	9	\N
65	2013-06-14 13:31:55.696654	2013-06-14 13:31:55.769748	127.0.0.1	3	604	22	REG-FRED_A	f	9	\N
66	2013-06-14 13:31:55.792083	2013-06-14 13:31:55.815799	127.0.0.1	3	101	22	REG-FRED_A	f	13	\N
67	2013-06-14 13:31:55.918068	2013-06-14 13:31:55.952544	127.0.0.1	3	100	23	REG-FRED_A	f	9	\N
68	2013-06-14 13:31:55.976723	2013-06-14 13:31:56.049872	127.0.0.1	3	604	23	REG-FRED_A	f	9	\N
69	2013-06-14 13:31:56.073097	2013-06-14 13:31:56.097205	127.0.0.1	3	101	23	REG-FRED_A	f	13	\N
70	2013-06-14 13:31:56.193554	2013-06-14 13:31:56.228549	127.0.0.1	3	100	24	REG-FRED_A	f	9	\N
71	2013-06-14 13:31:56.252318	2013-06-14 13:31:56.325582	127.0.0.1	3	604	24	REG-FRED_A	f	9	\N
72	2013-06-14 13:31:56.348027	2013-06-14 13:31:56.372282	127.0.0.1	3	101	24	REG-FRED_A	f	13	\N
73	2013-06-14 13:31:56.474393	2013-06-14 13:31:56.509372	127.0.0.1	3	100	25	REG-FRED_A	f	9	\N
74	2013-06-14 13:31:56.53354	2013-06-14 13:31:56.607377	127.0.0.1	3	604	25	REG-FRED_A	f	9	\N
75	2013-06-14 13:31:56.630762	2013-06-14 13:31:56.654774	127.0.0.1	3	101	25	REG-FRED_A	f	13	\N
76	2013-06-14 13:31:56.756571	2013-06-14 13:31:56.791669	127.0.0.1	3	100	26	REG-FRED_A	f	9	\N
77	2013-06-14 13:31:56.815828	2013-06-14 13:31:56.891198	127.0.0.1	3	604	26	REG-FRED_A	f	9	\N
78	2013-06-14 13:31:56.91392	2013-06-14 13:31:56.938157	127.0.0.1	3	101	26	REG-FRED_A	f	13	\N
79	2013-06-14 13:31:57.037095	2013-06-14 13:31:57.072101	127.0.0.1	3	100	27	REG-FRED_A	f	9	\N
80	2013-06-14 13:31:57.099624	2013-06-14 13:31:57.172801	127.0.0.1	3	604	27	REG-FRED_A	f	9	\N
81	2013-06-14 13:31:57.195262	2013-06-14 13:31:57.219424	127.0.0.1	3	101	27	REG-FRED_A	f	13	\N
82	2013-06-14 13:31:57.314593	2013-06-14 13:31:57.343268	127.0.0.1	3	100	28	REG-FRED_A	f	9	\N
83	2013-06-14 13:31:57.367545	2013-06-14 13:31:57.474439	127.0.0.1	3	504	28	REG-FRED_A	f	9	\N
84	2013-06-14 13:31:57.497802	2013-06-14 13:31:57.521916	127.0.0.1	3	101	28	REG-FRED_A	f	13	\N
85	2013-06-14 13:31:57.615419	2013-06-14 13:31:57.650012	127.0.0.1	3	100	29	REG-FRED_A	f	9	\N
86	2013-06-14 13:31:57.67431	2013-06-14 13:31:57.777055	127.0.0.1	3	504	29	REG-FRED_A	f	9	\N
87	2013-06-14 13:31:57.799648	2013-06-14 13:31:57.823839	127.0.0.1	3	101	29	REG-FRED_A	f	13	\N
88	2013-06-14 13:31:57.930438	2013-06-14 13:31:57.965181	127.0.0.1	3	100	30	REG-FRED_A	f	9	\N
89	2013-06-14 13:31:57.989386	2013-06-14 13:31:58.092567	127.0.0.1	3	504	30	REG-FRED_A	f	9	\N
90	2013-06-14 13:31:58.115984	2013-06-14 13:31:58.14052	127.0.0.1	3	101	30	REG-FRED_A	f	13	\N
91	2013-06-14 13:31:58.249341	2013-06-14 13:31:58.283973	127.0.0.1	3	100	31	REG-FRED_A	f	9	\N
92	2013-06-14 13:31:58.308432	2013-06-14 13:31:58.411446	127.0.0.1	3	504	31	REG-FRED_A	f	9	\N
93	2013-06-14 13:31:58.434833	2013-06-14 13:31:58.459075	127.0.0.1	3	101	31	REG-FRED_A	f	13	\N
94	2013-06-14 13:31:58.557735	2013-06-14 13:31:58.592726	127.0.0.1	3	100	32	REG-FRED_A	f	9	\N
95	2013-06-14 13:31:58.621642	2013-06-14 13:31:58.724399	127.0.0.1	3	504	32	REG-FRED_A	f	9	\N
96	2013-06-14 13:31:58.747057	2013-06-14 13:31:58.77087	127.0.0.1	3	101	32	REG-FRED_A	f	13	\N
97	2013-06-14 13:31:58.868199	2013-06-14 13:31:58.903343	127.0.0.1	3	100	33	REG-FRED_A	f	9	\N
98	2013-06-14 13:31:58.927217	2013-06-14 13:31:59.031993	127.0.0.1	3	504	33	REG-FRED_A	f	9	\N
99	2013-06-14 13:31:59.055859	2013-06-14 13:31:59.080319	127.0.0.1	3	101	33	REG-FRED_A	f	13	\N
100	2013-06-14 13:31:59.178127	2013-06-14 13:31:59.213336	127.0.0.1	3	100	34	REG-FRED_A	f	9	\N
101	2013-06-14 13:31:59.237565	2013-06-14 13:31:59.340577	127.0.0.1	3	504	34	REG-FRED_A	f	9	\N
102	2013-06-14 13:31:59.364126	2013-06-14 13:31:59.388443	127.0.0.1	3	101	34	REG-FRED_A	f	13	\N
103	2013-06-14 13:31:59.488069	2013-06-14 13:31:59.523314	127.0.0.1	3	100	35	REG-FRED_A	f	9	\N
104	2013-06-14 13:31:59.54742	2013-06-14 13:31:59.654478	127.0.0.1	3	504	35	REG-FRED_A	f	9	\N
105	2013-06-14 13:31:59.678123	2013-06-14 13:31:59.702396	127.0.0.1	3	101	35	REG-FRED_A	f	13	\N
106	2013-06-14 13:31:59.799385	2013-06-14 13:31:59.834185	127.0.0.1	3	100	36	REG-FRED_A	f	9	\N
107	2013-06-14 13:31:59.858572	2013-06-14 13:31:59.961387	127.0.0.1	3	504	36	REG-FRED_A	f	9	\N
108	2013-06-14 13:31:59.984729	2013-06-14 13:32:00.009087	127.0.0.1	3	101	36	REG-FRED_A	f	13	\N
109	2013-06-14 13:32:00.10372	2013-06-14 13:32:00.138732	127.0.0.1	3	100	37	REG-FRED_A	f	9	\N
110	2013-06-14 13:32:00.163381	2013-06-14 13:32:00.266532	127.0.0.1	3	504	37	REG-FRED_A	f	9	\N
111	2013-06-14 13:32:00.290621	2013-06-14 13:32:00.315403	127.0.0.1	3	101	37	REG-FRED_A	f	13	\N
112	2013-06-14 13:32:00.411361	2013-06-14 13:32:00.445977	127.0.0.1	3	100	38	REG-FRED_A	f	9	\N
113	2013-06-14 13:32:00.470148	2013-06-14 13:32:00.568077	127.0.0.1	3	504	38	REG-FRED_A	f	9	\N
114	2013-06-14 13:32:00.590745	2013-06-14 13:32:00.614877	127.0.0.1	3	101	38	REG-FRED_A	f	13	\N
115	2013-06-14 13:32:00.710188	2013-06-14 13:32:00.745192	127.0.0.1	3	100	39	REG-FRED_A	f	9	\N
116	2013-06-14 13:32:00.76986	2013-06-14 13:32:00.868331	127.0.0.1	3	504	39	REG-FRED_A	f	9	\N
117	2013-06-14 13:32:00.89147	2013-06-14 13:32:00.91579	127.0.0.1	3	101	39	REG-FRED_A	f	13	\N
118	2013-06-14 13:32:01.015982	2013-06-14 13:32:01.050761	127.0.0.1	3	100	40	REG-FRED_A	f	9	\N
119	2013-06-14 13:32:01.07493	2013-06-14 13:32:01.173465	127.0.0.1	3	504	40	REG-FRED_A	f	9	\N
120	2013-06-14 13:32:01.196397	2013-06-14 13:32:01.220412	127.0.0.1	3	101	40	REG-FRED_A	f	13	\N
121	2013-06-14 13:32:01.328519	2013-06-14 13:32:01.363557	127.0.0.1	3	100	41	REG-FRED_A	f	9	\N
122	2013-06-14 13:32:01.387742	2013-06-14 13:32:01.485915	127.0.0.1	3	504	41	REG-FRED_A	f	9	\N
123	2013-06-14 13:32:01.509354	2013-06-14 13:32:01.53338	127.0.0.1	3	101	41	REG-FRED_A	f	13	\N
124	2013-06-14 13:32:01.638268	2013-06-14 13:32:01.673352	127.0.0.1	3	100	42	REG-FRED_A	f	9	\N
125	2013-06-14 13:32:01.69753	2013-06-14 13:32:01.79559	127.0.0.1	3	504	42	REG-FRED_A	f	9	\N
126	2013-06-14 13:32:01.819018	2013-06-14 13:32:01.84324	127.0.0.1	3	101	42	REG-FRED_A	f	13	\N
127	2013-06-14 13:32:01.958009	2013-06-14 13:32:01.993028	127.0.0.1	3	100	43	REG-FRED_A	f	9	\N
128	2013-06-14 13:32:02.01731	2013-06-14 13:32:02.115868	127.0.0.1	3	504	43	REG-FRED_A	f	9	\N
129	2013-06-14 13:32:02.140865	2013-06-14 13:32:02.165043	127.0.0.1	3	101	43	REG-FRED_A	f	13	\N
130	2013-06-14 13:32:02.260969	2013-06-14 13:32:02.297026	127.0.0.1	3	100	44	REG-FRED_A	f	9	\N
131	2013-06-14 13:32:02.321543	2013-06-14 13:32:02.419751	127.0.0.1	3	504	44	REG-FRED_A	f	9	\N
132	2013-06-14 13:32:02.442676	2013-06-14 13:32:02.466736	127.0.0.1	3	101	44	REG-FRED_A	f	13	\N
133	2013-06-14 13:32:02.566777	2013-06-14 13:32:02.601934	127.0.0.1	3	100	45	REG-FRED_A	f	9	\N
134	2013-06-14 13:32:02.626066	2013-06-14 13:32:02.724371	127.0.0.1	3	504	45	REG-FRED_A	f	9	\N
135	2013-06-14 13:32:02.747333	2013-06-14 13:32:02.771593	127.0.0.1	3	101	45	REG-FRED_A	f	13	\N
136	2013-06-14 13:32:02.868341	2013-06-14 13:32:02.903381	127.0.0.1	3	100	46	REG-FRED_A	f	9	\N
137	2013-06-14 13:32:02.928105	2013-06-14 13:32:03.026671	127.0.0.1	3	504	46	REG-FRED_A	f	9	\N
138	2013-06-14 13:32:03.050358	2013-06-14 13:32:03.074349	127.0.0.1	3	101	46	REG-FRED_A	f	13	\N
139	2013-06-14 13:32:03.164551	2013-06-14 13:32:03.199491	127.0.0.1	3	100	47	REG-FRED_A	f	9	\N
140	2013-06-14 13:32:03.223592	2013-06-14 13:32:03.321496	127.0.0.1	3	504	47	REG-FRED_A	f	9	\N
141	2013-06-14 13:32:03.344442	2013-06-14 13:32:03.368655	127.0.0.1	3	101	47	REG-FRED_A	f	13	\N
142	2013-06-14 13:32:03.470343	2013-06-14 13:32:03.505382	127.0.0.1	3	100	48	REG-FRED_A	f	9	\N
143	2013-06-14 13:32:03.529912	2013-06-14 13:32:03.63664	127.0.0.1	3	504	48	REG-FRED_A	f	9	\N
144	2013-06-14 13:32:03.659433	2013-06-14 13:32:03.683599	127.0.0.1	3	101	48	REG-FRED_A	f	13	\N
145	2013-06-14 13:32:03.78648	2013-06-14 13:32:03.821102	127.0.0.1	3	100	49	REG-FRED_A	f	9	\N
146	2013-06-14 13:32:03.845724	2013-06-14 13:32:03.953403	127.0.0.1	3	504	49	REG-FRED_A	f	9	\N
147	2013-06-14 13:32:03.975974	2013-06-14 13:32:04.000057	127.0.0.1	3	101	49	REG-FRED_A	f	13	\N
148	2013-06-14 13:32:04.106177	2013-06-14 13:32:04.141329	127.0.0.1	3	100	50	REG-FRED_A	f	9	\N
149	2013-06-14 13:32:04.16571	2013-06-14 13:32:04.270894	127.0.0.1	3	504	50	REG-FRED_A	f	9	\N
150	2013-06-14 13:32:04.293804	2013-06-14 13:32:04.318189	127.0.0.1	3	101	50	REG-FRED_A	f	13	\N
151	2013-06-14 13:32:04.424238	2013-06-14 13:32:04.458783	127.0.0.1	3	100	51	REG-FRED_A	f	9	\N
152	2013-06-14 13:32:04.483171	2013-06-14 13:32:04.588052	127.0.0.1	3	504	51	REG-FRED_A	f	9	\N
153	2013-06-14 13:32:04.610724	2013-06-14 13:32:04.634431	127.0.0.1	3	101	51	REG-FRED_A	f	13	\N
154	2013-06-14 13:32:04.740122	2013-06-14 13:32:04.775175	127.0.0.1	3	100	52	REG-FRED_A	f	9	\N
155	2013-06-14 13:32:04.799478	2013-06-14 13:32:04.905281	127.0.0.1	3	504	52	REG-FRED_A	f	9	\N
156	2013-06-14 13:32:04.928523	2013-06-14 13:32:04.952539	127.0.0.1	3	101	52	REG-FRED_A	f	13	\N
157	2013-06-14 13:32:05.057386	2013-06-14 13:32:05.092582	127.0.0.1	3	100	53	REG-FRED_A	f	9	\N
158	2013-06-14 13:32:05.117046	2013-06-14 13:32:05.222617	127.0.0.1	3	504	53	REG-FRED_A	f	9	\N
159	2013-06-14 13:32:05.245854	2013-06-14 13:32:05.270062	127.0.0.1	3	101	53	REG-FRED_A	f	13	\N
160	2013-06-14 13:32:05.37904	2013-06-14 13:32:05.414157	127.0.0.1	3	100	54	REG-FRED_A	f	9	\N
161	2013-06-14 13:32:05.438573	2013-06-14 13:32:05.543747	127.0.0.1	3	504	54	REG-FRED_A	f	9	\N
162	2013-06-14 13:32:05.567124	2013-06-14 13:32:05.591293	127.0.0.1	3	101	54	REG-FRED_A	f	13	\N
163	2013-06-14 13:32:05.69046	2013-06-14 13:32:05.723321	127.0.0.1	3	100	55	REG-FRED_A	f	9	\N
164	2013-06-14 13:32:05.747844	2013-06-14 13:32:05.85294	127.0.0.1	3	504	55	REG-FRED_A	f	9	\N
165	2013-06-14 13:32:05.875628	2013-06-14 13:32:05.899465	127.0.0.1	3	101	55	REG-FRED_A	f	13	\N
166	2013-06-14 13:32:05.998781	2013-06-14 13:32:06.033842	127.0.0.1	3	100	56	REG-FRED_A	f	9	\N
167	2013-06-14 13:32:06.058387	2013-06-14 13:32:06.163322	127.0.0.1	3	504	56	REG-FRED_A	f	9	\N
168	2013-06-14 13:32:06.186072	2013-06-14 13:32:06.210144	127.0.0.1	3	101	56	REG-FRED_A	f	13	\N
169	2013-06-14 13:32:06.308321	2013-06-14 13:32:06.340903	127.0.0.1	3	100	57	REG-FRED_A	f	9	\N
170	2013-06-14 13:32:06.36519	2013-06-14 13:32:06.470626	127.0.0.1	3	504	57	REG-FRED_A	f	9	\N
171	2013-06-14 13:32:06.493315	2013-06-14 13:32:06.517173	127.0.0.1	3	101	57	REG-FRED_A	f	13	\N
172	2013-06-14 13:32:06.617628	2013-06-14 13:32:06.652364	127.0.0.1	3	100	58	REG-FRED_A	f	9	\N
173	2013-06-14 13:32:06.676859	2013-06-14 13:32:06.781899	127.0.0.1	3	504	58	REG-FRED_A	f	9	\N
174	2013-06-14 13:32:06.805535	2013-06-14 13:32:06.829669	127.0.0.1	3	101	58	REG-FRED_A	f	13	\N
\.


--
-- Data for Name: request_fee_parameter; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY request_fee_parameter (id, valid_from, count_free_base, count_free_per_domain, zone_id) FROM stdin;
1	2013-06-14 13:29:04.367276	5	1	2
\.


--
-- Data for Name: request_fee_registrar_parameter; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY request_fee_registrar_parameter (registrar_id, request_price_limit, email, telephone) FROM stdin;
\.


--
-- Data for Name: request_object_ref; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY request_object_ref (id, request_time_begin, request_service_id, request_monitoring, request_id, object_type_id, object_id) FROM stdin;
\.


--
-- Data for Name: request_object_type; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY request_object_type (id, name) FROM stdin;
1	contact
2	nsset
3	domain
4	keyset
5	registrar
6	mail
7	file
8	publicrequest
9	invoice
10	bankstatement
11	request
12	message
\.


--
-- Data for Name: request_property_name; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY request_property_name (id, name) FROM stdin;
1	registrarId
2	lang
3	password
4	clTRID
5	svTRID
6	rc
7	msg
8	searchAxis
9	type
10	handle
11	recursion
12	status
13	queryType
14	id
15	name
16	registrant
17	period
18	timeunit
19	creationDate
20	newPassword
21	checkId
22	available
23	reason
24	curExDate
25	renewPeriod
26	nsset
27	keyset
28	authInfo
29	username
30	session_id
31	result_size
32	filter_Service
33	negation
34	object_id
35	pi.name
36	pi.organization
37	pi.street
38	pi.city
39	pi.postalCode
40	pi.countryCode
41	email
42	discl.policy
43	discl.name
44	discl.org
45	discl.addr
46	discl.voice
47	discl.fax
48	discl.email
49	discl.vat
50	discl.ident
51	discl.notifyEmail
52	ident
53	identType
54	admin
55	reportLevel
56	ns.name
57	techC
58	filter_TimeBegin
59	msgId
60	url
61	errorType
62	voice
63	fax
64	filter_IsMonitoring
65	filter_Type
66	filter_CreateTime
67	filter_ZoneFqdn
68	filter_Handle
69	filter_AccountDate
70	vat
71	notifyEmail
72	addAdmin
73	remAdmin
74	errors
75	ns.addr
76	pi.state
77	domainId
78	remTmpcontact
79	filter_Registrant.Handle
80	filter_Registrar.Handle
81	filter_KeySet.Handle
82	filter_or
83	filter_RequestHandle
84	filter_SvTRID
85	filter_Time
86	filter_AdminContact.Handle
87	filter_TempContact.Handle
88	filter_Name
89	addNs.name
90	remNs
91	filter_CancelDate
92	filter_OutZoneDate
93	filter_Registrant.Name
94	filter_ExpirationDate
95	addNs.addr
96	filter_NSSet.Handle
97	filter_Organization
98	filter_Ssn
99	addTechC
100	remTechC
101	publicrequest_id
102	filter_TechContact.Handle
103	keys.flags
104	keys.protocol
105	keys.alg
106	keys.publicKey
107	techContact
108	filter_Email
109	result
110	filter_Message
111	payment_id
112	registrar_handle
113	filter_HostIP
114	filter_HostFQDN
115	filter_TechContact.Email
116	filter_TechContact.Name
117	set_countryCode
118	set_telephone
119	set_zones
120	set_id
121	set_city
122	set_ico
123	set_access
124	set_varSymb
125	set_hidden
126	set_email
127	set_vat
128	set_fax
129	set_handle
130	set_street1
131	set_street2
132	set_street3
133	set_postalcode
134	set_stateorprovince
135	set_name
136	set_url
137	set_dic
138	set_organization
139	filter_Registrant.Email
140	addKeys.flags
141	addKeys.protocol
142	addKeys.alg
143	addKeys.publicKey
144	remKeys.flags
145	remKeys.protocol
146	remKeys.alg
147	remKeys.publicKey
148	filter_Object.Handle
149	filter_Response
150	filter_AccountNumber
151	filter_VarSymb
152	filter_TaxDate
153	filter_Registrar.Name
154	filter_NotifyEmail
157	filter_Id
158	filter_Vat
159	filter_EmailToAnswer
160	filter_ResolveTime
161	filter_DeleteTime
162	filter_ActionType
163	filter_Object.AuthInfo
164	filter_Number
165	filter_TimeEnd
166	filter_UserName
167	filter_Status
168	addTech
169	filter_Registrar.Organization
156	filter_RequestPropertyValue.Value
171	filter_CreateRegistrar.Handle
172	count
173	zone
174	credit
175	set_visible_fieldsets_ids
176	set_password
177	set_md5Cert
178	set_DELETE
179	set_fromDate
180	set_toDate
183	filter_InvoiceId
184	filter_ServiceType
185	filter_CrDate
186	account_state
187	method
188	username_from_handle
189	send_me_news
190	first_name
191	last_name
192	phone_number
193	street1
194	street2
195	street3
196	city
197	postal_code
198	country
199	request_hash
200	request_mode
201	realm
202	assoc_handle
203	return_to
204	identity
205	claimed_id
206	pape_max_auth_age
207	response_mode
208	response_claimed_id
209	pape_auth_time
210	nickname
211	sreg_required
212	sreg_optional
213	sreg_returned
214	realmbag
215	trusted_attr
216	trusted
217	ax_required
218	ax_returned
219	pape_preferred_auth_policies
220	ax_optional
221	distrusted_attr
222	student
223	id_card_num
224	birth_date
225	filter_MessageType
226	Address
227	OPERATION
228	passport_num
229	disclose_email
230	disclose_phone
231	disclose_vat
232	disclose_ident
233	disclose_notify_email
234	disclose_fax
235	image
236	organization
237	vat_reg_num
238	vat_id_num
239	filter_RequestType
240	filter_CommType
241	state
242	IMAccount
243	URLAddress
244	pape_auth_policies
245	Phone
246	number
247	Email
248	ssn_id_num
249	remTech
250	filter_SourceIp
251	filter_NSSet.HostFQDN
252	filter_ObjectState.StateId
253	source
254	prefix
255	set_country
256	test_domain
155	filter_RequestPropertyValue.Name
170	filter_NSSet.TechContact.Handle
181	filter_Registrant.Registrar.Organization
182	filter_Registrant.Organization
257	filter_AccountId
258	filter_ClTRID
259	filter_MessageContact.Handle
260	filter_PhoneNumber
261	filter_SmsPhoneNumber
262	address
263	phone
264	pape_preferred_auth_level_types
265	auth_info
266	filter_TransferTime
267	filter_UpdateTime
268	filter_ModDate
269	level
270	ax_store_succeeded
271	ax_store_error
272	filter_ModifyTime
273	filter_CrTime
274	send_info
275	registration_nonce
276	immediate
277	email_change_request
278	urladdress
279	imaccount
280	number_change_request
281	filter_Registrant.Ssn
282	filter_Registrant.NotifyEmail
283	filter_AdminContact.Email
284	filter_AdminContact.NotifyEmail
285	filter_TempContact.Email
286	set_evaluation_file_id
287	set_score
288	set_uploaded_file
289	set_evaluation_file
290	display_trust
291	password_active
292	filter_Registrant.Vat
293	certificate_active
294	filter_Attempt
295	filter_LetterAddrName
296	keep_session
297	filter_TechContact.CreateTime
298	filter_UpdateRegistrar.Organization
299	filter_NSSet.TechContact.Email
300	filter_CreateRegistrar.Name
301	filter_AuthInfo
\.


--
-- Data for Name: request_property_value; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY request_property_value (request_time_begin, request_service_id, request_monitoring, id, request_id, property_name_id, value, output, parent_id) FROM stdin;
\.


--
-- Data for Name: request_property_value_epp_13_06; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY request_property_value_epp_13_06 (request_time_begin, request_service_id, request_monitoring, id, request_id, property_name_id, value, output, parent_id) FROM stdin;
2013-06-14 13:31:49.377405	3	f	1	1	1	REG-FRED_A	f	\N
2013-06-14 13:31:49.377405	3	f	2	1	2	EN	f	\N
2013-06-14 13:31:49.377405	3	f	3	1	3	passwd	f	\N
2013-06-14 13:31:49.377405	3	f	4	1	4	acef001#13-06-14at15:31:49	f	\N
2013-06-14 13:31:49.377405	3	f	5	1	5	ReqID-0000000001	t	\N
2013-06-14 13:31:49.377405	3	f	6	1	6	1000	t	\N
2013-06-14 13:31:49.377405	3	f	7	1	7	Command completed successfully	t	\N
2013-06-14 13:31:49.459803	3	f	8	2	10	CONTACT	f	\N
2013-06-14 13:31:49.459803	3	f	9	2	35	Freddy First	f	\N
2013-06-14 13:31:49.459803	3	f	10	2	36	Company Fred s.p.z.o.	f	\N
2013-06-14 13:31:49.459803	3	f	11	2	37	Wallstreet 16/3	f	\N
2013-06-14 13:31:49.459803	3	f	12	2	38	New York	f	\N
2013-06-14 13:31:49.459803	3	f	13	2	39	12601	f	\N
2013-06-14 13:31:49.459803	3	f	14	2	40	CZ	f	\N
2013-06-14 13:31:49.459803	3	f	15	2	62	+420.726123455	f	\N
2013-06-14 13:31:49.459803	3	f	16	2	63	+420.726123456	f	\N
2013-06-14 13:31:49.459803	3	f	17	2	41	freddy.first@nic.czcz	f	\N
2013-06-14 13:31:49.459803	3	f	18	2	42	public	f	\N
2013-06-14 13:31:49.459803	3	f	19	2	43	false	f	\N
2013-06-14 13:31:49.459803	3	f	20	2	44	false	f	\N
2013-06-14 13:31:49.459803	3	f	21	2	45	false	f	\N
2013-06-14 13:31:49.459803	3	f	22	2	46	false	f	\N
2013-06-14 13:31:49.459803	3	f	23	2	47	true	f	\N
2013-06-14 13:31:49.459803	3	f	24	2	48	false	f	\N
2013-06-14 13:31:49.459803	3	f	25	2	49	true	f	\N
2013-06-14 13:31:49.459803	3	f	26	2	50	true	f	\N
2013-06-14 13:31:49.459803	3	f	27	2	51	true	f	\N
2013-06-14 13:31:49.459803	3	f	28	2	70	CZ1234567889	f	\N
2013-06-14 13:31:49.459803	3	f	29	2	52	84956250	f	\N
2013-06-14 13:31:49.459803	3	f	30	2	53	ID card	f	\N
2013-06-14 13:31:49.459803	3	f	31	2	71	freddy+notify@nic.czcz	f	\N
2013-06-14 13:31:49.459803	3	f	32	2	4	acef002#13-06-14at15:31:49	f	\N
2013-06-14 13:31:49.459803	3	f	33	2	5	ReqID-0000000002	t	\N
2013-06-14 13:31:49.459803	3	f	34	2	6	1000	t	\N
2013-06-14 13:31:49.459803	3	f	35	2	7	Command completed successfully	t	\N
2013-06-14 13:31:49.459803	3	f	36	2	19	2013-06-14T15:31:49+02:00	t	\N
2013-06-14 13:31:49.578717	3	f	37	3	4	acef003#13-06-14at15:31:49	f	\N
2013-06-14 13:31:49.578717	3	f	38	3	5	ReqID-0000000003	t	\N
2013-06-14 13:31:49.578717	3	f	39	3	6	1500	t	\N
2013-06-14 13:31:49.578717	3	f	40	3	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:49.696274	3	f	41	4	1	REG-FRED_A	f	\N
2013-06-14 13:31:49.696274	3	f	42	4	2	EN	f	\N
2013-06-14 13:31:49.696274	3	f	43	4	3	passwd	f	\N
2013-06-14 13:31:49.696274	3	f	44	4	4	tett001#13-06-14at15:31:49	f	\N
2013-06-14 13:31:49.696274	3	f	45	4	5	ReqID-0000000004	t	\N
2013-06-14 13:31:49.696274	3	f	46	4	6	1000	t	\N
2013-06-14 13:31:49.696274	3	f	47	4	7	Command completed successfully	t	\N
2013-06-14 13:31:49.756596	3	f	48	5	10	CIHAK	f	\N
2013-06-14 13:31:49.756596	3	f	49	5	35	Řehoř Čihák	f	\N
2013-06-14 13:31:49.756596	3	f	50	5	36	Firma Čihák a spol.	f	\N
2013-06-14 13:31:49.756596	3	f	51	5	37	Přípotoční 16/3	f	\N
2013-06-14 13:31:49.756596	3	f	52	5	38	Říčany u Prahy	f	\N
2013-06-14 13:31:49.756596	3	f	53	5	39	12601	f	\N
2013-06-14 13:31:49.756596	3	f	54	5	40	CZ	f	\N
2013-06-14 13:31:49.756596	3	f	55	5	62	+420.726123456	f	\N
2013-06-14 13:31:49.756596	3	f	56	5	63	+420.726123455	f	\N
2013-06-14 13:31:49.756596	3	f	57	5	41	rehor.cihak@nic.czcz	f	\N
2013-06-14 13:31:49.756596	3	f	58	5	42	public	f	\N
2013-06-14 13:31:49.756596	3	f	59	5	43	false	f	\N
2013-06-14 13:31:49.756596	3	f	60	5	44	false	f	\N
2013-06-14 13:31:49.756596	3	f	61	5	45	false	f	\N
2013-06-14 13:31:49.756596	3	f	62	5	46	false	f	\N
2013-06-14 13:31:49.756596	3	f	63	5	47	true	f	\N
2013-06-14 13:31:49.756596	3	f	64	5	48	false	f	\N
2013-06-14 13:31:49.756596	3	f	65	5	49	true	f	\N
2013-06-14 13:31:49.756596	3	f	66	5	50	true	f	\N
2013-06-14 13:31:49.756596	3	f	67	5	51	true	f	\N
2013-06-14 13:31:49.756596	3	f	68	5	70	CZ1234567890	f	\N
2013-06-14 13:31:49.756596	3	f	69	5	52	84956251	f	\N
2013-06-14 13:31:49.756596	3	f	70	5	53	ID card	f	\N
2013-06-14 13:31:49.756596	3	f	71	5	71	cihak+notify@nic.czcz	f	\N
2013-06-14 13:31:49.756596	3	f	72	5	4	tett002#13-06-14at15:31:49	f	\N
2013-06-14 13:31:49.756596	3	f	73	5	5	ReqID-0000000005	t	\N
2013-06-14 13:31:49.756596	3	f	74	5	6	1000	t	\N
2013-06-14 13:31:49.756596	3	f	75	5	7	Command completed successfully	t	\N
2013-06-14 13:31:49.756596	3	f	76	5	19	2013-06-14T15:31:49+02:00	t	\N
2013-06-14 13:31:49.867874	3	f	77	6	4	tett003#13-06-14at15:31:49	f	\N
2013-06-14 13:31:49.867874	3	f	78	6	5	ReqID-0000000006	t	\N
2013-06-14 13:31:49.867874	3	f	79	6	6	1500	t	\N
2013-06-14 13:31:49.867874	3	f	80	6	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:49.990702	3	f	81	7	1	REG-FRED_A	f	\N
2013-06-14 13:31:49.990702	3	f	82	7	2	EN	f	\N
2013-06-14 13:31:49.990702	3	f	83	7	3	passwd	f	\N
2013-06-14 13:31:49.990702	3	f	84	7	4	kvuh001#13-06-14at15:31:49	f	\N
2013-06-14 13:31:49.990702	3	f	85	7	5	ReqID-0000000007	t	\N
2013-06-14 13:31:49.990702	3	f	86	7	6	1000	t	\N
2013-06-14 13:31:49.990702	3	f	87	7	7	Command completed successfully	t	\N
2013-06-14 13:31:50.051062	3	f	88	8	10	PEPA	f	\N
2013-06-14 13:31:50.051062	3	f	89	8	35	Pepa Zdepa	f	\N
2013-06-14 13:31:50.051062	3	f	90	8	36	Firma Pepa s.r.o.	f	\N
2013-06-14 13:31:50.051062	3	f	91	8	37	U práce 453	f	\N
2013-06-14 13:31:50.051062	3	f	92	8	38	Praha	f	\N
2013-06-14 13:31:50.051062	3	f	93	8	39	12300	f	\N
2013-06-14 13:31:50.051062	3	f	94	8	40	CZ	f	\N
2013-06-14 13:31:50.051062	3	f	95	8	62	+420.726123457	f	\N
2013-06-14 13:31:50.051062	3	f	96	8	63	+420.726123454	f	\N
2013-06-14 13:31:50.051062	3	f	97	8	41	pepa.zdepa@nic.czcz	f	\N
2013-06-14 13:31:50.051062	3	f	98	8	42	public	f	\N
2013-06-14 13:31:50.051062	3	f	99	8	43	false	f	\N
2013-06-14 13:31:50.051062	3	f	100	8	44	false	f	\N
2013-06-14 13:31:50.051062	3	f	101	8	45	false	f	\N
2013-06-14 13:31:50.051062	3	f	102	8	46	false	f	\N
2013-06-14 13:31:50.051062	3	f	103	8	47	true	f	\N
2013-06-14 13:31:50.051062	3	f	104	8	48	false	f	\N
2013-06-14 13:31:50.051062	3	f	105	8	49	true	f	\N
2013-06-14 13:31:50.051062	3	f	106	8	50	true	f	\N
2013-06-14 13:31:50.051062	3	f	107	8	51	true	f	\N
2013-06-14 13:31:50.051062	3	f	108	8	70	CZ1234567891	f	\N
2013-06-14 13:31:50.051062	3	f	109	8	52	84956252	f	\N
2013-06-14 13:31:50.051062	3	f	110	8	53	ID card	f	\N
2013-06-14 13:31:50.051062	3	f	111	8	71	pepa+notify@nic.czcz	f	\N
2013-06-14 13:31:50.051062	3	f	112	8	4	kvuh002#13-06-14at15:31:50	f	\N
2013-06-14 13:31:50.051062	3	f	113	8	5	ReqID-0000000008	t	\N
2013-06-14 13:31:50.051062	3	f	114	8	6	1000	t	\N
2013-06-14 13:31:50.051062	3	f	115	8	7	Command completed successfully	t	\N
2013-06-14 13:31:50.051062	3	f	116	8	19	2013-06-14T15:31:50+02:00	t	\N
2013-06-14 13:31:50.163623	3	f	117	9	4	kvuh003#13-06-14at15:31:50	f	\N
2013-06-14 13:31:50.163623	3	f	118	9	5	ReqID-0000000009	t	\N
2013-06-14 13:31:50.163623	3	f	119	9	6	1500	t	\N
2013-06-14 13:31:50.163623	3	f	120	9	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:50.28923	3	f	121	10	1	REG-FRED_A	f	\N
2013-06-14 13:31:50.28923	3	f	122	10	2	EN	f	\N
2013-06-14 13:31:50.28923	3	f	123	10	3	passwd	f	\N
2013-06-14 13:31:50.28923	3	f	124	10	4	uswf001#13-06-14at15:31:50	f	\N
2013-06-14 13:31:50.28923	3	f	125	10	5	ReqID-0000000010	t	\N
2013-06-14 13:31:50.28923	3	f	126	10	6	1000	t	\N
2013-06-14 13:31:50.28923	3	f	127	10	7	Command completed successfully	t	\N
2013-06-14 13:31:50.349693	3	f	128	11	10	ANNA	f	\N
2013-06-14 13:31:50.349693	3	f	129	11	35	Anna Procházková	f	\N
2013-06-14 13:31:50.349693	3	f	130	11	37	Za želvami 32	f	\N
2013-06-14 13:31:50.349693	3	f	131	11	38	Louňovice	f	\N
2013-06-14 13:31:50.349693	3	f	132	11	39	12808	f	\N
2013-06-14 13:31:50.349693	3	f	133	11	40	CZ	f	\N
2013-06-14 13:31:50.349693	3	f	134	11	62	+420.726123458	f	\N
2013-06-14 13:31:50.349693	3	f	135	11	63	+420.726123453	f	\N
2013-06-14 13:31:50.349693	3	f	136	11	41	anna.prochazkova@nic.czcz	f	\N
2013-06-14 13:31:50.349693	3	f	137	11	42	public	f	\N
2013-06-14 13:31:50.349693	3	f	138	11	43	false	f	\N
2013-06-14 13:31:50.349693	3	f	139	11	44	false	f	\N
2013-06-14 13:31:50.349693	3	f	140	11	45	false	f	\N
2013-06-14 13:31:50.349693	3	f	141	11	46	false	f	\N
2013-06-14 13:31:50.349693	3	f	142	11	47	true	f	\N
2013-06-14 13:31:50.349693	3	f	143	11	48	false	f	\N
2013-06-14 13:31:50.349693	3	f	144	11	49	true	f	\N
2013-06-14 13:31:50.349693	3	f	145	11	50	true	f	\N
2013-06-14 13:31:50.349693	3	f	146	11	51	true	f	\N
2013-06-14 13:31:50.349693	3	f	147	11	70	CZ1234567892	f	\N
2013-06-14 13:31:50.349693	3	f	148	11	52	84956253	f	\N
2013-06-14 13:31:50.349693	3	f	149	11	53	ID card	f	\N
2013-06-14 13:31:50.349693	3	f	150	11	71	anna+notify@nic.czcz	f	\N
2013-06-14 13:31:50.349693	3	f	151	11	4	uswf002#13-06-14at15:31:50	f	\N
2013-06-14 13:31:50.349693	3	f	152	11	5	ReqID-0000000011	t	\N
2013-06-14 13:31:50.349693	3	f	153	11	6	1000	t	\N
2013-06-14 13:31:50.349693	3	f	154	11	7	Command completed successfully	t	\N
2013-06-14 13:31:50.349693	3	f	155	11	19	2013-06-14T15:31:50+02:00	t	\N
2013-06-14 13:31:50.459946	3	f	156	12	4	uswf003#13-06-14at15:31:50	f	\N
2013-06-14 13:31:50.459946	3	f	157	12	5	ReqID-0000000012	t	\N
2013-06-14 13:31:50.459946	3	f	158	12	6	1500	t	\N
2013-06-14 13:31:50.459946	3	f	159	12	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:50.589583	3	f	160	13	1	REG-FRED_A	f	\N
2013-06-14 13:31:50.589583	3	f	161	13	2	EN	f	\N
2013-06-14 13:31:50.589583	3	f	162	13	3	passwd	f	\N
2013-06-14 13:31:50.589583	3	f	163	13	4	zigy001#13-06-14at15:31:50	f	\N
2013-06-14 13:31:50.589583	3	f	164	13	5	ReqID-0000000013	t	\N
2013-06-14 13:31:50.589583	3	f	165	13	6	1000	t	\N
2013-06-14 13:31:50.589583	3	f	166	13	7	Command completed successfully	t	\N
2013-06-14 13:31:50.651337	3	f	167	14	10	FRANTA	f	\N
2013-06-14 13:31:50.651337	3	f	168	14	35	František Kocourek	f	\N
2013-06-14 13:31:50.651337	3	f	169	14	37	Žabovřesky 4567	f	\N
2013-06-14 13:31:50.651337	3	f	170	14	38	Brno	f	\N
2013-06-14 13:31:50.651337	3	f	171	14	39	18000	f	\N
2013-06-14 13:31:50.651337	3	f	172	14	40	CZ	f	\N
2013-06-14 13:31:50.651337	3	f	173	14	62	+420.726123459	f	\N
2013-06-14 13:31:50.651337	3	f	174	14	63	+420.726123452	f	\N
2013-06-14 13:31:50.651337	3	f	175	14	41	franta.kocourek@nic.czcz	f	\N
2013-06-14 13:31:50.651337	3	f	176	14	42	public	f	\N
2013-06-14 13:31:50.651337	3	f	177	14	43	false	f	\N
2013-06-14 13:31:50.651337	3	f	178	14	44	false	f	\N
2013-06-14 13:31:50.651337	3	f	179	14	45	false	f	\N
2013-06-14 13:31:50.651337	3	f	180	14	46	false	f	\N
2013-06-14 13:31:50.651337	3	f	181	14	47	true	f	\N
2013-06-14 13:31:50.651337	3	f	182	14	48	false	f	\N
2013-06-14 13:31:50.651337	3	f	183	14	49	true	f	\N
2013-06-14 13:31:50.651337	3	f	184	14	50	true	f	\N
2013-06-14 13:31:50.651337	3	f	185	14	51	true	f	\N
2013-06-14 13:31:50.651337	3	f	186	14	70	CZ1234567893	f	\N
2013-06-14 13:31:50.651337	3	f	187	14	52	84956254	f	\N
2013-06-14 13:31:50.651337	3	f	188	14	53	ID card	f	\N
2013-06-14 13:31:50.651337	3	f	189	14	71	franta+notify@nic.czcz	f	\N
2013-06-14 13:31:50.651337	3	f	190	14	4	zigy002#13-06-14at15:31:50	f	\N
2013-06-14 13:31:50.651337	3	f	191	14	5	ReqID-0000000014	t	\N
2013-06-14 13:31:50.651337	3	f	192	14	6	1000	t	\N
2013-06-14 13:31:50.651337	3	f	193	14	7	Command completed successfully	t	\N
2013-06-14 13:31:50.651337	3	f	194	14	19	2013-06-14T15:31:50+02:00	t	\N
2013-06-14 13:31:50.762072	3	f	195	15	4	zigy003#13-06-14at15:31:50	f	\N
2013-06-14 13:31:50.762072	3	f	196	15	5	ReqID-0000000015	t	\N
2013-06-14 13:31:50.762072	3	f	197	15	6	1500	t	\N
2013-06-14 13:31:50.762072	3	f	198	15	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:50.884535	3	f	199	16	1	REG-FRED_A	f	\N
2013-06-14 13:31:50.884535	3	f	200	16	2	EN	f	\N
2013-06-14 13:31:50.884535	3	f	201	16	3	passwd	f	\N
2013-06-14 13:31:50.884535	3	f	202	16	4	gtql001#13-06-14at15:31:50	f	\N
2013-06-14 13:31:50.884535	3	f	203	16	5	ReqID-0000000016	t	\N
2013-06-14 13:31:50.884535	3	f	204	16	6	1000	t	\N
2013-06-14 13:31:50.884535	3	f	205	16	7	Command completed successfully	t	\N
2013-06-14 13:31:50.944806	3	f	206	17	10	TESTER	f	\N
2013-06-14 13:31:50.944806	3	f	207	17	35	Tomáš Tester	f	\N
2013-06-14 13:31:50.944806	3	f	208	17	37	Testovní 35	f	\N
2013-06-14 13:31:50.944806	3	f	209	17	38	Plzeň	f	\N
2013-06-14 13:31:50.944806	3	f	210	17	39	16200	f	\N
2013-06-14 13:31:50.944806	3	f	211	17	40	CZ	f	\N
2013-06-14 13:31:50.944806	3	f	212	17	62	+420.726123460	f	\N
2013-06-14 13:31:50.944806	3	f	213	17	63	+420.726123451	f	\N
2013-06-14 13:31:50.944806	3	f	214	17	41	tomas.tester@nic.czcz	f	\N
2013-06-14 13:31:50.944806	3	f	215	17	42	public	f	\N
2013-06-14 13:31:50.944806	3	f	216	17	43	false	f	\N
2013-06-14 13:31:50.944806	3	f	217	17	44	false	f	\N
2013-06-14 13:31:50.944806	3	f	218	17	45	false	f	\N
2013-06-14 13:31:50.944806	3	f	219	17	46	false	f	\N
2013-06-14 13:31:50.944806	3	f	220	17	47	true	f	\N
2013-06-14 13:31:50.944806	3	f	221	17	48	false	f	\N
2013-06-14 13:31:50.944806	3	f	222	17	49	true	f	\N
2013-06-14 13:31:50.944806	3	f	223	17	50	true	f	\N
2013-06-14 13:31:50.944806	3	f	224	17	51	true	f	\N
2013-06-14 13:31:50.944806	3	f	225	17	70	CZ1234567894	f	\N
2013-06-14 13:31:50.944806	3	f	226	17	52	84956253	f	\N
2013-06-14 13:31:50.944806	3	f	227	17	53	ID card	f	\N
2013-06-14 13:31:50.944806	3	f	228	17	71	tester+notify@nic.czcz	f	\N
2013-06-14 13:31:50.944806	3	f	229	17	4	gtql002#13-06-14at15:31:50	f	\N
2013-06-14 13:31:50.944806	3	f	230	17	5	ReqID-0000000017	t	\N
2013-06-14 13:31:50.944806	3	f	231	17	6	1000	t	\N
2013-06-14 13:31:50.944806	3	f	232	17	7	Command completed successfully	t	\N
2013-06-14 13:31:50.944806	3	f	233	17	19	2013-06-14T15:31:50+02:00	t	\N
2013-06-14 13:31:51.059879	3	f	234	18	4	gtql003#13-06-14at15:31:51	f	\N
2013-06-14 13:31:51.059879	3	f	235	18	5	ReqID-0000000018	t	\N
2013-06-14 13:31:51.059879	3	f	236	18	6	1500	t	\N
2013-06-14 13:31:51.059879	3	f	237	18	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:51.189496	3	f	238	19	1	REG-FRED_A	f	\N
2013-06-14 13:31:51.189496	3	f	239	19	2	EN	f	\N
2013-06-14 13:31:51.189496	3	f	240	19	3	passwd	f	\N
2013-06-14 13:31:51.189496	3	f	241	19	4	szql001#13-06-14at15:31:51	f	\N
2013-06-14 13:31:51.189496	3	f	242	19	5	ReqID-0000000019	t	\N
2013-06-14 13:31:51.189496	3	f	243	19	6	1000	t	\N
2013-06-14 13:31:51.189496	3	f	244	19	7	Command completed successfully	t	\N
2013-06-14 13:31:51.250398	3	f	245	20	10	BOB	f	\N
2013-06-14 13:31:51.250398	3	f	246	20	35	Bobeš Šuflík	f	\N
2013-06-14 13:31:51.250398	3	f	247	20	37	Báňská 35	f	\N
2013-06-14 13:31:51.250398	3	f	248	20	38	Domažlice	f	\N
2013-06-14 13:31:51.250398	3	f	249	20	39	18200	f	\N
2013-06-14 13:31:51.250398	3	f	250	20	40	CZ	f	\N
2013-06-14 13:31:51.250398	3	f	251	20	62	+420.726123461	f	\N
2013-06-14 13:31:51.250398	3	f	252	20	63	+420.726123450	f	\N
2013-06-14 13:31:51.250398	3	f	253	20	41	bobes.suflik@nic.czcz	f	\N
2013-06-14 13:31:51.250398	3	f	254	20	42	public	f	\N
2013-06-14 13:31:51.250398	3	f	255	20	43	false	f	\N
2013-06-14 13:31:51.250398	3	f	256	20	44	false	f	\N
2013-06-14 13:31:51.250398	3	f	257	20	45	false	f	\N
2013-06-14 13:31:51.250398	3	f	258	20	46	false	f	\N
2013-06-14 13:31:51.250398	3	f	259	20	47	true	f	\N
2013-06-14 13:31:51.250398	3	f	260	20	48	false	f	\N
2013-06-14 13:31:51.250398	3	f	261	20	49	true	f	\N
2013-06-14 13:31:51.250398	3	f	262	20	50	true	f	\N
2013-06-14 13:31:51.250398	3	f	263	20	51	true	f	\N
2013-06-14 13:31:51.250398	3	f	264	20	70	CZ1234567895	f	\N
2013-06-14 13:31:51.250398	3	f	265	20	52	84956252	f	\N
2013-06-14 13:31:51.250398	3	f	266	20	53	ID card	f	\N
2013-06-14 13:31:51.250398	3	f	267	20	71	bob+notify@nic.czcz	f	\N
2013-06-14 13:31:51.250398	3	f	268	20	4	szql002#13-06-14at15:31:51	f	\N
2013-06-14 13:31:51.250398	3	f	269	20	5	ReqID-0000000020	t	\N
2013-06-14 13:31:51.250398	3	f	270	20	6	1000	t	\N
2013-06-14 13:31:51.250398	3	f	271	20	7	Command completed successfully	t	\N
2013-06-14 13:31:51.250398	3	f	272	20	19	2013-06-14T15:31:51+02:00	t	\N
2013-06-14 13:31:51.361512	3	f	273	21	4	szql003#13-06-14at15:31:51	f	\N
2013-06-14 13:31:51.361512	3	f	274	21	5	ReqID-0000000021	t	\N
2013-06-14 13:31:51.361512	3	f	275	21	6	1500	t	\N
2013-06-14 13:31:51.361512	3	f	276	21	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:51.613755	3	f	277	22	1	REG-FRED_A	f	\N
2013-06-14 13:31:51.613755	3	f	278	22	2	EN	f	\N
2013-06-14 13:31:51.613755	3	f	279	22	3	passwd	f	\N
2013-06-14 13:31:51.613755	3	f	280	22	4	iyyh001#13-06-14at15:31:51	f	\N
2013-06-14 13:31:51.613755	3	f	281	22	5	ReqID-0000000022	t	\N
2013-06-14 13:31:51.613755	3	f	282	22	6	1000	t	\N
2013-06-14 13:31:51.613755	3	f	283	22	7	Command completed successfully	t	\N
2013-06-14 13:31:51.672815	3	f	284	23	10	nssid01	f	\N
2013-06-14 13:31:51.672815	3	f	285	23	56	ns1.domain.cz	f	\N
2013-06-14 13:31:51.672815	3	f	286	23	75	217.31.207.130	f	285
2013-06-14 13:31:51.672815	3	f	287	23	75	217.31.207.129	f	285
2013-06-14 13:31:51.672815	3	f	288	23	56	ns2.domain.cz	f	\N
2013-06-14 13:31:51.672815	3	f	289	23	75	217.31.206.130	f	288
2013-06-14 13:31:51.672815	3	f	290	23	75	217.31.206.129	f	288
2013-06-14 13:31:51.672815	3	f	291	23	57	TESTER	f	\N
2013-06-14 13:31:51.672815	3	f	292	23	57	anna	f	\N
2013-06-14 13:31:51.672815	3	f	293	23	4	iyyh002#13-06-14at15:31:51	f	\N
2013-06-14 13:31:51.672815	3	f	294	23	5	ReqID-0000000023	t	\N
2013-06-14 13:31:51.672815	3	f	295	23	6	1000	t	\N
2013-06-14 13:31:51.672815	3	f	296	23	7	Command completed successfully	t	\N
2013-06-14 13:31:51.672815	3	f	297	23	19	2013-06-14T15:31:51+02:00	t	\N
2013-06-14 13:31:51.785499	3	f	298	24	4	iyyh003#13-06-14at15:31:51	f	\N
2013-06-14 13:31:51.785499	3	f	299	24	5	ReqID-0000000024	t	\N
2013-06-14 13:31:51.785499	3	f	300	24	6	1500	t	\N
2013-06-14 13:31:51.785499	3	f	301	24	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:51.902495	3	f	302	25	1	REG-FRED_A	f	\N
2013-06-14 13:31:51.902495	3	f	303	25	2	EN	f	\N
2013-06-14 13:31:51.902495	3	f	304	25	3	passwd	f	\N
2013-06-14 13:31:51.902495	3	f	305	25	4	ovie001#13-06-14at15:31:51	f	\N
2013-06-14 13:31:51.902495	3	f	306	25	5	ReqID-0000000025	t	\N
2013-06-14 13:31:51.902495	3	f	307	25	6	1000	t	\N
2013-06-14 13:31:51.902495	3	f	308	25	7	Command completed successfully	t	\N
2013-06-14 13:31:51.961345	3	f	309	26	10	nssid02	f	\N
2013-06-14 13:31:51.961345	3	f	310	26	56	ns1.domain.cz	f	\N
2013-06-14 13:31:51.961345	3	f	311	26	75	217.31.207.130	f	310
2013-06-14 13:31:51.961345	3	f	312	26	75	217.31.207.129	f	310
2013-06-14 13:31:51.961345	3	f	313	26	56	ns2.domain.cz	f	\N
2013-06-14 13:31:51.961345	3	f	314	26	75	217.31.206.130	f	313
2013-06-14 13:31:51.961345	3	f	315	26	75	217.31.206.129	f	313
2013-06-14 13:31:51.961345	3	f	316	26	57	TESTER	f	\N
2013-06-14 13:31:51.961345	3	f	317	26	57	anna	f	\N
2013-06-14 13:31:51.961345	3	f	318	26	4	ovie002#13-06-14at15:31:51	f	\N
2013-06-14 13:31:51.961345	3	f	319	26	5	ReqID-0000000026	t	\N
2013-06-14 13:31:51.961345	3	f	320	26	6	1000	t	\N
2013-06-14 13:31:51.961345	3	f	321	26	7	Command completed successfully	t	\N
2013-06-14 13:31:51.961345	3	f	322	26	19	2013-06-14T15:31:51+02:00	t	\N
2013-06-14 13:31:52.070041	3	f	323	27	4	ovie003#13-06-14at15:31:52	f	\N
2013-06-14 13:31:52.070041	3	f	324	27	5	ReqID-0000000027	t	\N
2013-06-14 13:31:52.070041	3	f	325	27	6	1500	t	\N
2013-06-14 13:31:52.070041	3	f	326	27	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:52.19672	3	f	327	28	1	REG-FRED_A	f	\N
2013-06-14 13:31:52.19672	3	f	328	28	2	EN	f	\N
2013-06-14 13:31:52.19672	3	f	329	28	3	passwd	f	\N
2013-06-14 13:31:52.19672	3	f	330	28	4	vsvn001#13-06-14at15:31:52	f	\N
2013-06-14 13:31:52.19672	3	f	331	28	5	ReqID-0000000028	t	\N
2013-06-14 13:31:52.19672	3	f	332	28	6	1000	t	\N
2013-06-14 13:31:52.19672	3	f	333	28	7	Command completed successfully	t	\N
2013-06-14 13:31:52.25608	3	f	334	29	10	nssid03	f	\N
2013-06-14 13:31:52.25608	3	f	335	29	56	ns1.domain.cz	f	\N
2013-06-14 13:31:52.25608	3	f	336	29	75	217.31.207.130	f	335
2013-06-14 13:31:52.25608	3	f	337	29	75	217.31.207.129	f	335
2013-06-14 13:31:52.25608	3	f	338	29	56	ns2.domain.cz	f	\N
2013-06-14 13:31:52.25608	3	f	339	29	75	217.31.206.130	f	338
2013-06-14 13:31:52.25608	3	f	340	29	75	217.31.206.129	f	338
2013-06-14 13:31:52.25608	3	f	341	29	57	TESTER	f	\N
2013-06-14 13:31:52.25608	3	f	342	29	57	anna	f	\N
2013-06-14 13:31:52.25608	3	f	343	29	4	vsvn002#13-06-14at15:31:52	f	\N
2013-06-14 13:31:52.25608	3	f	344	29	5	ReqID-0000000029	t	\N
2013-06-14 13:31:52.25608	3	f	345	29	6	1000	t	\N
2013-06-14 13:31:52.25608	3	f	346	29	7	Command completed successfully	t	\N
2013-06-14 13:31:52.25608	3	f	347	29	19	2013-06-14T15:31:52+02:00	t	\N
2013-06-14 13:31:52.365794	3	f	348	30	4	vsvn003#13-06-14at15:31:52	f	\N
2013-06-14 13:31:52.365794	3	f	349	30	5	ReqID-0000000030	t	\N
2013-06-14 13:31:52.365794	3	f	350	30	6	1500	t	\N
2013-06-14 13:31:52.365794	3	f	351	30	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:52.487891	3	f	352	31	1	REG-FRED_A	f	\N
2013-06-14 13:31:52.487891	3	f	353	31	2	EN	f	\N
2013-06-14 13:31:52.487891	3	f	354	31	3	passwd	f	\N
2013-06-14 13:31:52.487891	3	f	355	31	4	jdtt001#13-06-14at15:31:52	f	\N
2013-06-14 13:31:52.487891	3	f	356	31	5	ReqID-0000000031	t	\N
2013-06-14 13:31:52.487891	3	f	357	31	6	1000	t	\N
2013-06-14 13:31:52.487891	3	f	358	31	7	Command completed successfully	t	\N
2013-06-14 13:31:52.547287	3	f	359	32	10	nssid04	f	\N
2013-06-14 13:31:52.547287	3	f	360	32	56	ns1.domain.cz	f	\N
2013-06-14 13:31:52.547287	3	f	361	32	75	217.31.207.130	f	360
2013-06-14 13:31:52.547287	3	f	362	32	75	217.31.207.129	f	360
2013-06-14 13:31:52.547287	3	f	363	32	56	ns2.domain.cz	f	\N
2013-06-14 13:31:52.547287	3	f	364	32	75	217.31.206.130	f	363
2013-06-14 13:31:52.547287	3	f	365	32	75	217.31.206.129	f	363
2013-06-14 13:31:52.547287	3	f	366	32	57	TESTER	f	\N
2013-06-14 13:31:52.547287	3	f	367	32	57	anna	f	\N
2013-06-14 13:31:52.547287	3	f	368	32	4	jdtt002#13-06-14at15:31:52	f	\N
2013-06-14 13:31:52.547287	3	f	369	32	5	ReqID-0000000032	t	\N
2013-06-14 13:31:52.547287	3	f	370	32	6	1000	t	\N
2013-06-14 13:31:52.547287	3	f	371	32	7	Command completed successfully	t	\N
2013-06-14 13:31:52.547287	3	f	372	32	19	2013-06-14T15:31:52+02:00	t	\N
2013-06-14 13:31:52.638	3	f	373	33	4	jdtt003#13-06-14at15:31:52	f	\N
2013-06-14 13:31:52.638	3	f	374	33	5	ReqID-0000000033	t	\N
2013-06-14 13:31:52.638	3	f	375	33	6	1500	t	\N
2013-06-14 13:31:52.638	3	f	376	33	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:52.769179	3	f	377	34	1	REG-FRED_A	f	\N
2013-06-14 13:31:52.769179	3	f	378	34	2	EN	f	\N
2013-06-14 13:31:52.769179	3	f	379	34	3	passwd	f	\N
2013-06-14 13:31:52.769179	3	f	380	34	4	ekkx001#13-06-14at15:31:52	f	\N
2013-06-14 13:31:52.769179	3	f	381	34	5	ReqID-0000000034	t	\N
2013-06-14 13:31:52.769179	3	f	382	34	6	1000	t	\N
2013-06-14 13:31:52.769179	3	f	383	34	7	Command completed successfully	t	\N
2013-06-14 13:31:52.827942	3	f	384	35	10	nssid05	f	\N
2013-06-14 13:31:52.827942	3	f	385	35	56	ns1.domain.cz	f	\N
2013-06-14 13:31:52.827942	3	f	386	35	75	217.31.207.130	f	385
2013-06-14 13:31:52.827942	3	f	387	35	75	217.31.207.129	f	385
2013-06-14 13:31:52.827942	3	f	388	35	56	ns2.domain.cz	f	\N
2013-06-14 13:31:52.827942	3	f	389	35	75	217.31.206.130	f	388
2013-06-14 13:31:52.827942	3	f	390	35	75	217.31.206.129	f	388
2013-06-14 13:31:52.827942	3	f	391	35	57	TESTER	f	\N
2013-06-14 13:31:52.827942	3	f	392	35	57	anna	f	\N
2013-06-14 13:31:52.827942	3	f	393	35	4	ekkx002#13-06-14at15:31:52	f	\N
2013-06-14 13:31:52.827942	3	f	394	35	5	ReqID-0000000035	t	\N
2013-06-14 13:31:52.827942	3	f	395	35	6	1000	t	\N
2013-06-14 13:31:52.827942	3	f	396	35	7	Command completed successfully	t	\N
2013-06-14 13:31:52.827942	3	f	397	35	19	2013-06-14T15:31:52+02:00	t	\N
2013-06-14 13:31:52.940235	3	f	398	36	4	ekkx003#13-06-14at15:31:52	f	\N
2013-06-14 13:31:52.940235	3	f	399	36	5	ReqID-0000000036	t	\N
2013-06-14 13:31:52.940235	3	f	400	36	6	1500	t	\N
2013-06-14 13:31:52.940235	3	f	401	36	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:53.060071	3	f	402	37	1	REG-FRED_A	f	\N
2013-06-14 13:31:53.060071	3	f	403	37	2	EN	f	\N
2013-06-14 13:31:53.060071	3	f	404	37	3	passwd	f	\N
2013-06-14 13:31:53.060071	3	f	405	37	4	mwqj001#13-06-14at15:31:53	f	\N
2013-06-14 13:31:53.060071	3	f	406	37	5	ReqID-0000000037	t	\N
2013-06-14 13:31:53.060071	3	f	407	37	6	1000	t	\N
2013-06-14 13:31:53.060071	3	f	408	37	7	Command completed successfully	t	\N
2013-06-14 13:31:53.119983	3	f	409	38	10	nssid06	f	\N
2013-06-14 13:31:53.119983	3	f	410	38	56	ns1.domain.cz	f	\N
2013-06-14 13:31:53.119983	3	f	411	38	75	217.31.207.130	f	410
2013-06-14 13:31:53.119983	3	f	412	38	75	217.31.207.129	f	410
2013-06-14 13:31:53.119983	3	f	413	38	56	ns2.domain.cz	f	\N
2013-06-14 13:31:53.119983	3	f	414	38	75	217.31.206.130	f	413
2013-06-14 13:31:53.119983	3	f	415	38	75	217.31.206.129	f	413
2013-06-14 13:31:53.119983	3	f	416	38	57	TESTER	f	\N
2013-06-14 13:31:53.119983	3	f	417	38	57	anna	f	\N
2013-06-14 13:31:53.119983	3	f	418	38	4	mwqj002#13-06-14at15:31:53	f	\N
2013-06-14 13:31:53.119983	3	f	419	38	5	ReqID-0000000038	t	\N
2013-06-14 13:31:53.119983	3	f	420	38	6	1000	t	\N
2013-06-14 13:31:53.119983	3	f	421	38	7	Command completed successfully	t	\N
2013-06-14 13:31:53.119983	3	f	422	38	19	2013-06-14T15:31:53+02:00	t	\N
2013-06-14 13:31:53.229053	3	f	423	39	4	mwqj003#13-06-14at15:31:53	f	\N
2013-06-14 13:31:53.229053	3	f	424	39	5	ReqID-0000000039	t	\N
2013-06-14 13:31:53.229053	3	f	425	39	6	1500	t	\N
2013-06-14 13:31:53.229053	3	f	426	39	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:53.356298	3	f	427	40	1	REG-FRED_A	f	\N
2013-06-14 13:31:53.356298	3	f	428	40	2	EN	f	\N
2013-06-14 13:31:53.356298	3	f	429	40	3	passwd	f	\N
2013-06-14 13:31:53.356298	3	f	430	40	4	mpmv001#13-06-14at15:31:53	f	\N
2013-06-14 13:31:53.356298	3	f	431	40	5	ReqID-0000000040	t	\N
2013-06-14 13:31:53.356298	3	f	432	40	6	1000	t	\N
2013-06-14 13:31:53.356298	3	f	433	40	7	Command completed successfully	t	\N
2013-06-14 13:31:53.415641	3	f	434	41	10	nssid07	f	\N
2013-06-14 13:31:53.415641	3	f	435	41	56	ns1.domain.cz	f	\N
2013-06-14 13:31:53.415641	3	f	436	41	75	217.31.207.130	f	435
2013-06-14 13:31:53.415641	3	f	437	41	75	217.31.207.129	f	435
2013-06-14 13:31:53.415641	3	f	438	41	56	ns2.domain.cz	f	\N
2013-06-14 13:31:53.415641	3	f	439	41	75	217.31.206.130	f	438
2013-06-14 13:31:53.415641	3	f	440	41	75	217.31.206.129	f	438
2013-06-14 13:31:53.415641	3	f	441	41	57	TESTER	f	\N
2013-06-14 13:31:53.415641	3	f	442	41	57	anna	f	\N
2013-06-14 13:31:53.415641	3	f	443	41	4	mpmv002#13-06-14at15:31:53	f	\N
2013-06-14 13:31:53.415641	3	f	444	41	5	ReqID-0000000041	t	\N
2013-06-14 13:31:53.415641	3	f	445	41	6	1000	t	\N
2013-06-14 13:31:53.415641	3	f	446	41	7	Command completed successfully	t	\N
2013-06-14 13:31:53.415641	3	f	447	41	19	2013-06-14T15:31:53+02:00	t	\N
2013-06-14 13:31:53.525063	3	f	448	42	4	mpmv003#13-06-14at15:31:53	f	\N
2013-06-14 13:31:53.525063	3	f	449	42	5	ReqID-0000000042	t	\N
2013-06-14 13:31:53.525063	3	f	450	42	6	1500	t	\N
2013-06-14 13:31:53.525063	3	f	451	42	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:53.650397	3	f	452	43	1	REG-FRED_A	f	\N
2013-06-14 13:31:53.650397	3	f	453	43	2	EN	f	\N
2013-06-14 13:31:53.650397	3	f	454	43	3	passwd	f	\N
2013-06-14 13:31:53.650397	3	f	455	43	4	fdjd001#13-06-14at15:31:53	f	\N
2013-06-14 13:31:53.650397	3	f	456	43	5	ReqID-0000000043	t	\N
2013-06-14 13:31:53.650397	3	f	457	43	6	1000	t	\N
2013-06-14 13:31:53.650397	3	f	458	43	7	Command completed successfully	t	\N
2013-06-14 13:31:53.70983	3	f	459	44	10	nssid08	f	\N
2013-06-14 13:31:53.70983	3	f	460	44	56	ns1.domain.cz	f	\N
2013-06-14 13:31:53.70983	3	f	461	44	75	217.31.207.130	f	460
2013-06-14 13:31:53.70983	3	f	462	44	75	217.31.207.129	f	460
2013-06-14 13:31:53.70983	3	f	463	44	56	ns2.domain.cz	f	\N
2013-06-14 13:31:53.70983	3	f	464	44	75	217.31.206.130	f	463
2013-06-14 13:31:53.70983	3	f	465	44	75	217.31.206.129	f	463
2013-06-14 13:31:53.70983	3	f	466	44	57	TESTER	f	\N
2013-06-14 13:31:53.70983	3	f	467	44	57	anna	f	\N
2013-06-14 13:31:53.70983	3	f	468	44	4	fdjd002#13-06-14at15:31:53	f	\N
2013-06-14 13:31:53.70983	3	f	469	44	5	ReqID-0000000044	t	\N
2013-06-14 13:31:53.70983	3	f	470	44	6	1000	t	\N
2013-06-14 13:31:53.70983	3	f	471	44	7	Command completed successfully	t	\N
2013-06-14 13:31:53.70983	3	f	472	44	19	2013-06-14T15:31:53+02:00	t	\N
2013-06-14 13:31:53.818889	3	f	473	45	4	fdjd003#13-06-14at15:31:53	f	\N
2013-06-14 13:31:53.818889	3	f	474	45	5	ReqID-0000000045	t	\N
2013-06-14 13:31:53.818889	3	f	475	45	6	1500	t	\N
2013-06-14 13:31:53.818889	3	f	476	45	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:53.948367	3	f	477	46	1	REG-FRED_A	f	\N
2013-06-14 13:31:53.948367	3	f	478	46	2	EN	f	\N
2013-06-14 13:31:53.948367	3	f	479	46	3	passwd	f	\N
2013-06-14 13:31:53.948367	3	f	480	46	4	sluv001#13-06-14at15:31:53	f	\N
2013-06-14 13:31:53.948367	3	f	481	46	5	ReqID-0000000046	t	\N
2013-06-14 13:31:53.948367	3	f	482	46	6	1000	t	\N
2013-06-14 13:31:53.948367	3	f	483	46	7	Command completed successfully	t	\N
2013-06-14 13:31:54.007041	3	f	484	47	10	nssid09	f	\N
2013-06-14 13:31:54.007041	3	f	485	47	56	ns1.domain.cz	f	\N
2013-06-14 13:31:54.007041	3	f	486	47	75	217.31.207.130	f	485
2013-06-14 13:31:54.007041	3	f	487	47	75	217.31.207.129	f	485
2013-06-14 13:31:54.007041	3	f	488	47	56	ns2.domain.cz	f	\N
2013-06-14 13:31:54.007041	3	f	489	47	75	217.31.206.130	f	488
2013-06-14 13:31:54.007041	3	f	490	47	75	217.31.206.129	f	488
2013-06-14 13:31:54.007041	3	f	491	47	57	TESTER	f	\N
2013-06-14 13:31:54.007041	3	f	492	47	57	anna	f	\N
2013-06-14 13:31:54.007041	3	f	493	47	4	sluv002#13-06-14at15:31:54	f	\N
2013-06-14 13:31:54.007041	3	f	494	47	5	ReqID-0000000047	t	\N
2013-06-14 13:31:54.007041	3	f	495	47	6	1000	t	\N
2013-06-14 13:31:54.007041	3	f	496	47	7	Command completed successfully	t	\N
2013-06-14 13:31:54.007041	3	f	497	47	19	2013-06-14T15:31:54+02:00	t	\N
2013-06-14 13:31:54.116438	3	f	498	48	4	sluv003#13-06-14at15:31:54	f	\N
2013-06-14 13:31:54.116438	3	f	499	48	5	ReqID-0000000048	t	\N
2013-06-14 13:31:54.116438	3	f	500	48	6	1500	t	\N
2013-06-14 13:31:54.116438	3	f	501	48	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:54.235866	3	f	502	49	1	REG-FRED_A	f	\N
2013-06-14 13:31:54.235866	3	f	503	49	2	EN	f	\N
2013-06-14 13:31:54.235866	3	f	504	49	3	passwd	f	\N
2013-06-14 13:31:54.235866	3	f	505	49	4	rqqp001#13-06-14at15:31:54	f	\N
2013-06-14 13:31:54.235866	3	f	506	49	5	ReqID-0000000049	t	\N
2013-06-14 13:31:54.235866	3	f	507	49	6	1000	t	\N
2013-06-14 13:31:54.235866	3	f	508	49	7	Command completed successfully	t	\N
2013-06-14 13:31:54.296205	3	f	509	50	10	nssid10	f	\N
2013-06-14 13:31:54.296205	3	f	510	50	56	ns1.domain.cz	f	\N
2013-06-14 13:31:54.296205	3	f	511	50	75	217.31.207.130	f	510
2013-06-14 13:31:54.296205	3	f	512	50	75	217.31.207.129	f	510
2013-06-14 13:31:54.296205	3	f	513	50	56	ns2.domain.cz	f	\N
2013-06-14 13:31:54.296205	3	f	514	50	75	217.31.206.130	f	513
2013-06-14 13:31:54.296205	3	f	515	50	75	217.31.206.129	f	513
2013-06-14 13:31:54.296205	3	f	516	50	57	TESTER	f	\N
2013-06-14 13:31:54.296205	3	f	517	50	57	anna	f	\N
2013-06-14 13:31:54.296205	3	f	518	50	4	rqqp002#13-06-14at15:31:54	f	\N
2013-06-14 13:31:54.296205	3	f	519	50	5	ReqID-0000000050	t	\N
2013-06-14 13:31:54.296205	3	f	520	50	6	1000	t	\N
2013-06-14 13:31:54.296205	3	f	521	50	7	Command completed successfully	t	\N
2013-06-14 13:31:54.296205	3	f	522	50	19	2013-06-14T15:31:54+02:00	t	\N
2013-06-14 13:31:54.405267	3	f	523	51	4	rqqp003#13-06-14at15:31:54	f	\N
2013-06-14 13:31:54.405267	3	f	524	51	5	ReqID-0000000051	t	\N
2013-06-14 13:31:54.405267	3	f	525	51	6	1500	t	\N
2013-06-14 13:31:54.405267	3	f	526	51	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:54.533374	3	f	527	52	1	REG-FRED_A	f	\N
2013-06-14 13:31:54.533374	3	f	528	52	2	EN	f	\N
2013-06-14 13:31:54.533374	3	f	529	52	3	passwd	f	\N
2013-06-14 13:31:54.533374	3	f	530	52	4	qlxb001#13-06-14at15:31:54	f	\N
2013-06-14 13:31:54.533374	3	f	531	52	5	ReqID-0000000052	t	\N
2013-06-14 13:31:54.533374	3	f	532	52	6	1000	t	\N
2013-06-14 13:31:54.533374	3	f	533	52	7	Command completed successfully	t	\N
2013-06-14 13:31:54.591899	3	f	534	53	10	keyid01	f	\N
2013-06-14 13:31:54.591899	3	f	535	53	103	257	f	\N
2013-06-14 13:31:54.591899	3	f	536	53	104	3	f	\N
2013-06-14 13:31:54.591899	3	f	537	53	105	5	f	\N
2013-06-14 13:31:54.591899	3	f	538	53	106	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8	f	\N
2013-06-14 13:31:54.591899	3	f	539	53	107	TESTER	f	\N
2013-06-14 13:31:54.591899	3	f	540	53	107	anna	f	\N
2013-06-14 13:31:54.591899	3	f	541	53	4	qlxb002#13-06-14at15:31:54	f	\N
2013-06-14 13:31:54.591899	3	f	542	53	5	ReqID-0000000053	t	\N
2013-06-14 13:31:54.591899	3	f	543	53	6	1000	t	\N
2013-06-14 13:31:54.591899	3	f	544	53	7	Command completed successfully	t	\N
2013-06-14 13:31:54.591899	3	f	545	53	19	2013-06-14T15:31:54+02:00	t	\N
2013-06-14 13:31:54.688549	3	f	546	54	4	qlxb003#13-06-14at15:31:54	f	\N
2013-06-14 13:31:54.688549	3	f	547	54	5	ReqID-0000000054	t	\N
2013-06-14 13:31:54.688549	3	f	548	54	6	1500	t	\N
2013-06-14 13:31:54.688549	3	f	549	54	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:54.817635	3	f	550	55	1	REG-FRED_A	f	\N
2013-06-14 13:31:54.817635	3	f	551	55	2	EN	f	\N
2013-06-14 13:31:54.817635	3	f	552	55	3	passwd	f	\N
2013-06-14 13:31:54.817635	3	f	553	55	4	stsl001#13-06-14at15:31:54	f	\N
2013-06-14 13:31:54.817635	3	f	554	55	5	ReqID-0000000055	t	\N
2013-06-14 13:31:54.817635	3	f	555	55	6	1000	t	\N
2013-06-14 13:31:54.817635	3	f	556	55	7	Command completed successfully	t	\N
2013-06-14 13:31:54.875497	3	f	557	56	10	keyid02	f	\N
2013-06-14 13:31:54.875497	3	f	558	56	103	257	f	\N
2013-06-14 13:31:54.875497	3	f	559	56	104	3	f	\N
2013-06-14 13:31:54.875497	3	f	560	56	105	5	f	\N
2013-06-14 13:31:54.875497	3	f	561	56	106	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8	f	\N
2013-06-14 13:31:54.875497	3	f	562	56	107	TESTER	f	\N
2013-06-14 13:31:54.875497	3	f	563	56	107	anna	f	\N
2013-06-14 13:31:54.875497	3	f	564	56	4	stsl002#13-06-14at15:31:54	f	\N
2013-06-14 13:31:54.875497	3	f	565	56	5	ReqID-0000000056	t	\N
2013-06-14 13:31:54.875497	3	f	566	56	6	1000	t	\N
2013-06-14 13:31:54.875497	3	f	567	56	7	Command completed successfully	t	\N
2013-06-14 13:31:54.875497	3	f	568	56	19	2013-06-14T15:31:54+02:00	t	\N
2013-06-14 13:31:54.950894	3	f	569	57	4	stsl003#13-06-14at15:31:54	f	\N
2013-06-14 13:31:54.950894	3	f	570	57	5	ReqID-0000000057	t	\N
2013-06-14 13:31:54.950894	3	f	571	57	6	1500	t	\N
2013-06-14 13:31:54.950894	3	f	572	57	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:55.076237	3	f	573	58	1	REG-FRED_A	f	\N
2013-06-14 13:31:55.076237	3	f	574	58	2	EN	f	\N
2013-06-14 13:31:55.076237	3	f	575	58	3	passwd	f	\N
2013-06-14 13:31:55.076237	3	f	576	58	4	mwwm001#13-06-14at15:31:55	f	\N
2013-06-14 13:31:55.076237	3	f	577	58	5	ReqID-0000000058	t	\N
2013-06-14 13:31:55.076237	3	f	578	58	6	1000	t	\N
2013-06-14 13:31:55.076237	3	f	579	58	7	Command completed successfully	t	\N
2013-06-14 13:31:55.135419	3	f	580	59	10	keyid03	f	\N
2013-06-14 13:31:55.135419	3	f	581	59	103	257	f	\N
2013-06-14 13:31:55.135419	3	f	582	59	104	3	f	\N
2013-06-14 13:31:55.135419	3	f	583	59	105	5	f	\N
2013-06-14 13:31:55.135419	3	f	584	59	106	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8	f	\N
2013-06-14 13:31:55.135419	3	f	585	59	107	TESTER	f	\N
2013-06-14 13:31:55.135419	3	f	586	59	107	anna	f	\N
2013-06-14 13:31:55.135419	3	f	587	59	4	mwwm002#13-06-14at15:31:55	f	\N
2013-06-14 13:31:55.135419	3	f	588	59	5	ReqID-0000000059	t	\N
2013-06-14 13:31:55.135419	3	f	589	59	6	1000	t	\N
2013-06-14 13:31:55.135419	3	f	590	59	7	Command completed successfully	t	\N
2013-06-14 13:31:55.135419	3	f	591	59	19	2013-06-14T15:31:55+02:00	t	\N
2013-06-14 13:31:55.23132	3	f	592	60	4	mwwm003#13-06-14at15:31:55	f	\N
2013-06-14 13:31:55.23132	3	f	593	60	5	ReqID-0000000060	t	\N
2013-06-14 13:31:55.23132	3	f	594	60	6	1500	t	\N
2013-06-14 13:31:55.23132	3	f	595	60	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:55.352745	3	f	596	61	1	REG-FRED_A	f	\N
2013-06-14 13:31:55.352745	3	f	597	61	2	EN	f	\N
2013-06-14 13:31:55.352745	3	f	598	61	3	passwd	f	\N
2013-06-14 13:31:55.352745	3	f	599	61	4	gtbn001#13-06-14at15:31:55	f	\N
2013-06-14 13:31:55.352745	3	f	600	61	5	ReqID-0000000061	t	\N
2013-06-14 13:31:55.352745	3	f	601	61	6	1000	t	\N
2013-06-14 13:31:55.352745	3	f	602	61	7	Command completed successfully	t	\N
2013-06-14 13:31:55.413411	3	f	603	62	10	keyid04	f	\N
2013-06-14 13:31:55.413411	3	f	604	62	103	257	f	\N
2013-06-14 13:31:55.413411	3	f	605	62	104	3	f	\N
2013-06-14 13:31:55.413411	3	f	606	62	105	5	f	\N
2013-06-14 13:31:55.413411	3	f	607	62	106	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8	f	\N
2013-06-14 13:31:55.413411	3	f	608	62	107	TESTER	f	\N
2013-06-14 13:31:55.413411	3	f	609	62	107	anna	f	\N
2013-06-14 13:31:55.413411	3	f	610	62	4	gtbn002#13-06-14at15:31:55	f	\N
2013-06-14 13:31:55.413411	3	f	611	62	5	ReqID-0000000062	t	\N
2013-06-14 13:31:55.413411	3	f	612	62	6	1000	t	\N
2013-06-14 13:31:55.413411	3	f	613	62	7	Command completed successfully	t	\N
2013-06-14 13:31:55.413411	3	f	614	62	19	2013-06-14T15:31:55+02:00	t	\N
2013-06-14 13:31:55.509039	3	f	615	63	4	gtbn003#13-06-14at15:31:55	f	\N
2013-06-14 13:31:55.509039	3	f	616	63	5	ReqID-0000000063	t	\N
2013-06-14 13:31:55.509039	3	f	617	63	6	1500	t	\N
2013-06-14 13:31:55.509039	3	f	618	63	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:55.637527	3	f	619	64	1	REG-FRED_A	f	\N
2013-06-14 13:31:55.637527	3	f	620	64	2	EN	f	\N
2013-06-14 13:31:55.637527	3	f	621	64	3	passwd	f	\N
2013-06-14 13:31:55.637527	3	f	622	64	4	vxjb001#13-06-14at15:31:55	f	\N
2013-06-14 13:31:55.637527	3	f	623	64	5	ReqID-0000000064	t	\N
2013-06-14 13:31:55.637527	3	f	624	64	6	1000	t	\N
2013-06-14 13:31:55.637527	3	f	625	64	7	Command completed successfully	t	\N
2013-06-14 13:31:55.696654	3	f	626	65	10	keyid05	f	\N
2013-06-14 13:31:55.696654	3	f	627	65	103	257	f	\N
2013-06-14 13:31:55.696654	3	f	628	65	104	3	f	\N
2013-06-14 13:31:55.696654	3	f	629	65	105	5	f	\N
2013-06-14 13:31:55.696654	3	f	630	65	106	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8	f	\N
2013-06-14 13:31:55.696654	3	f	631	65	107	TESTER	f	\N
2013-06-14 13:31:55.696654	3	f	632	65	107	anna	f	\N
2013-06-14 13:31:55.696654	3	f	633	65	4	vxjb002#13-06-14at15:31:55	f	\N
2013-06-14 13:31:55.696654	3	f	634	65	5	ReqID-0000000065	t	\N
2013-06-14 13:31:55.696654	3	f	635	65	6	1000	t	\N
2013-06-14 13:31:55.696654	3	f	636	65	7	Command completed successfully	t	\N
2013-06-14 13:31:55.696654	3	f	637	65	19	2013-06-14T15:31:55+02:00	t	\N
2013-06-14 13:31:55.792083	3	f	638	66	4	vxjb003#13-06-14at15:31:55	f	\N
2013-06-14 13:31:55.792083	3	f	639	66	5	ReqID-0000000066	t	\N
2013-06-14 13:31:55.792083	3	f	640	66	6	1500	t	\N
2013-06-14 13:31:55.792083	3	f	641	66	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:55.918068	3	f	642	67	1	REG-FRED_A	f	\N
2013-06-14 13:31:55.918068	3	f	643	67	2	EN	f	\N
2013-06-14 13:31:55.918068	3	f	644	67	3	passwd	f	\N
2013-06-14 13:31:55.918068	3	f	645	67	4	lpeq001#13-06-14at15:31:55	f	\N
2013-06-14 13:31:55.918068	3	f	646	67	5	ReqID-0000000067	t	\N
2013-06-14 13:31:55.918068	3	f	647	67	6	1000	t	\N
2013-06-14 13:31:55.918068	3	f	648	67	7	Command completed successfully	t	\N
2013-06-14 13:31:55.976723	3	f	649	68	10	keyid06	f	\N
2013-06-14 13:31:55.976723	3	f	650	68	103	257	f	\N
2013-06-14 13:31:55.976723	3	f	651	68	104	3	f	\N
2013-06-14 13:31:55.976723	3	f	652	68	105	5	f	\N
2013-06-14 13:31:55.976723	3	f	653	68	106	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8	f	\N
2013-06-14 13:31:55.976723	3	f	654	68	107	TESTER	f	\N
2013-06-14 13:31:55.976723	3	f	655	68	107	anna	f	\N
2013-06-14 13:31:55.976723	3	f	656	68	4	lpeq002#13-06-14at15:31:55	f	\N
2013-06-14 13:31:55.976723	3	f	657	68	5	ReqID-0000000068	t	\N
2013-06-14 13:31:55.976723	3	f	658	68	6	1000	t	\N
2013-06-14 13:31:55.976723	3	f	659	68	7	Command completed successfully	t	\N
2013-06-14 13:31:55.976723	3	f	660	68	19	2013-06-14T15:31:56+02:00	t	\N
2013-06-14 13:31:56.073097	3	f	661	69	4	lpeq003#13-06-14at15:31:56	f	\N
2013-06-14 13:31:56.073097	3	f	662	69	5	ReqID-0000000069	t	\N
2013-06-14 13:31:56.073097	3	f	663	69	6	1500	t	\N
2013-06-14 13:31:56.073097	3	f	664	69	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:56.193554	3	f	665	70	1	REG-FRED_A	f	\N
2013-06-14 13:31:56.193554	3	f	666	70	2	EN	f	\N
2013-06-14 13:31:56.193554	3	f	667	70	3	passwd	f	\N
2013-06-14 13:31:56.193554	3	f	668	70	4	cjpd001#13-06-14at15:31:56	f	\N
2013-06-14 13:31:56.193554	3	f	669	70	5	ReqID-0000000070	t	\N
2013-06-14 13:31:56.193554	3	f	670	70	6	1000	t	\N
2013-06-14 13:31:56.193554	3	f	671	70	7	Command completed successfully	t	\N
2013-06-14 13:31:56.252318	3	f	672	71	10	keyid07	f	\N
2013-06-14 13:31:56.252318	3	f	673	71	103	257	f	\N
2013-06-14 13:31:56.252318	3	f	674	71	104	3	f	\N
2013-06-14 13:31:56.252318	3	f	675	71	105	5	f	\N
2013-06-14 13:31:56.252318	3	f	676	71	106	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8	f	\N
2013-06-14 13:31:56.252318	3	f	677	71	107	TESTER	f	\N
2013-06-14 13:31:56.252318	3	f	678	71	107	anna	f	\N
2013-06-14 13:31:56.252318	3	f	679	71	4	cjpd002#13-06-14at15:31:56	f	\N
2013-06-14 13:31:56.252318	3	f	680	71	5	ReqID-0000000071	t	\N
2013-06-14 13:31:56.252318	3	f	681	71	6	1000	t	\N
2013-06-14 13:31:56.252318	3	f	682	71	7	Command completed successfully	t	\N
2013-06-14 13:31:56.252318	3	f	683	71	19	2013-06-14T15:31:56+02:00	t	\N
2013-06-14 13:31:56.348027	3	f	684	72	4	cjpd003#13-06-14at15:31:56	f	\N
2013-06-14 13:31:56.348027	3	f	685	72	5	ReqID-0000000072	t	\N
2013-06-14 13:31:56.348027	3	f	686	72	6	1500	t	\N
2013-06-14 13:31:56.348027	3	f	687	72	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:56.474393	3	f	688	73	1	REG-FRED_A	f	\N
2013-06-14 13:31:56.474393	3	f	689	73	2	EN	f	\N
2013-06-14 13:31:56.474393	3	f	690	73	3	passwd	f	\N
2013-06-14 13:31:56.474393	3	f	691	73	4	wlmd001#13-06-14at15:31:56	f	\N
2013-06-14 13:31:56.474393	3	f	692	73	5	ReqID-0000000073	t	\N
2013-06-14 13:31:56.474393	3	f	693	73	6	1000	t	\N
2013-06-14 13:31:56.474393	3	f	694	73	7	Command completed successfully	t	\N
2013-06-14 13:31:56.53354	3	f	695	74	10	keyid08	f	\N
2013-06-14 13:31:56.53354	3	f	696	74	103	257	f	\N
2013-06-14 13:31:56.53354	3	f	697	74	104	3	f	\N
2013-06-14 13:31:56.53354	3	f	698	74	105	5	f	\N
2013-06-14 13:31:56.53354	3	f	699	74	106	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8	f	\N
2013-06-14 13:31:56.53354	3	f	700	74	107	TESTER	f	\N
2013-06-14 13:31:56.53354	3	f	701	74	107	anna	f	\N
2013-06-14 13:31:56.53354	3	f	702	74	4	wlmd002#13-06-14at15:31:56	f	\N
2013-06-14 13:31:56.53354	3	f	703	74	5	ReqID-0000000074	t	\N
2013-06-14 13:31:56.53354	3	f	704	74	6	1000	t	\N
2013-06-14 13:31:56.53354	3	f	705	74	7	Command completed successfully	t	\N
2013-06-14 13:31:56.53354	3	f	706	74	19	2013-06-14T15:31:56+02:00	t	\N
2013-06-14 13:31:56.630762	3	f	707	75	4	wlmd003#13-06-14at15:31:56	f	\N
2013-06-14 13:31:56.630762	3	f	708	75	5	ReqID-0000000075	t	\N
2013-06-14 13:31:56.630762	3	f	709	75	6	1500	t	\N
2013-06-14 13:31:56.630762	3	f	710	75	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:56.756571	3	f	711	76	1	REG-FRED_A	f	\N
2013-06-14 13:31:56.756571	3	f	712	76	2	EN	f	\N
2013-06-14 13:31:56.756571	3	f	713	76	3	passwd	f	\N
2013-06-14 13:31:56.756571	3	f	714	76	4	przn001#13-06-14at15:31:56	f	\N
2013-06-14 13:31:56.756571	3	f	715	76	5	ReqID-0000000076	t	\N
2013-06-14 13:31:56.756571	3	f	716	76	6	1000	t	\N
2013-06-14 13:31:56.756571	3	f	717	76	7	Command completed successfully	t	\N
2013-06-14 13:31:56.815828	3	f	718	77	10	keyid09	f	\N
2013-06-14 13:31:56.815828	3	f	719	77	103	257	f	\N
2013-06-14 13:31:56.815828	3	f	720	77	104	3	f	\N
2013-06-14 13:31:56.815828	3	f	721	77	105	5	f	\N
2013-06-14 13:31:56.815828	3	f	722	77	106	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8	f	\N
2013-06-14 13:31:56.815828	3	f	723	77	107	TESTER	f	\N
2013-06-14 13:31:56.815828	3	f	724	77	107	anna	f	\N
2013-06-14 13:31:56.815828	3	f	725	77	4	przn002#13-06-14at15:31:56	f	\N
2013-06-14 13:31:56.815828	3	f	726	77	5	ReqID-0000000077	t	\N
2013-06-14 13:31:56.815828	3	f	727	77	6	1000	t	\N
2013-06-14 13:31:56.815828	3	f	728	77	7	Command completed successfully	t	\N
2013-06-14 13:31:56.815828	3	f	729	77	19	2013-06-14T15:31:56+02:00	t	\N
2013-06-14 13:31:56.91392	3	f	730	78	4	przn003#13-06-14at15:31:56	f	\N
2013-06-14 13:31:56.91392	3	f	731	78	5	ReqID-0000000078	t	\N
2013-06-14 13:31:56.91392	3	f	732	78	6	1500	t	\N
2013-06-14 13:31:56.91392	3	f	733	78	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:57.037095	3	f	734	79	1	REG-FRED_A	f	\N
2013-06-14 13:31:57.037095	3	f	735	79	2	EN	f	\N
2013-06-14 13:31:57.037095	3	f	736	79	3	passwd	f	\N
2013-06-14 13:31:57.037095	3	f	737	79	4	jydo001#13-06-14at15:31:57	f	\N
2013-06-14 13:31:57.037095	3	f	738	79	5	ReqID-0000000079	t	\N
2013-06-14 13:31:57.037095	3	f	739	79	6	1000	t	\N
2013-06-14 13:31:57.037095	3	f	740	79	7	Command completed successfully	t	\N
2013-06-14 13:31:57.099624	3	f	741	80	10	keyid10	f	\N
2013-06-14 13:31:57.099624	3	f	742	80	103	257	f	\N
2013-06-14 13:31:57.099624	3	f	743	80	104	3	f	\N
2013-06-14 13:31:57.099624	3	f	744	80	105	5	f	\N
2013-06-14 13:31:57.099624	3	f	745	80	106	AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8	f	\N
2013-06-14 13:31:57.099624	3	f	746	80	107	TESTER	f	\N
2013-06-14 13:31:57.099624	3	f	747	80	107	anna	f	\N
2013-06-14 13:31:57.099624	3	f	748	80	4	jydo002#13-06-14at15:31:57	f	\N
2013-06-14 13:31:57.099624	3	f	749	80	5	ReqID-0000000080	t	\N
2013-06-14 13:31:57.099624	3	f	750	80	6	1000	t	\N
2013-06-14 13:31:57.099624	3	f	751	80	7	Command completed successfully	t	\N
2013-06-14 13:31:57.099624	3	f	752	80	19	2013-06-14T15:31:57+02:00	t	\N
2013-06-14 13:31:57.195262	3	f	753	81	4	jydo003#13-06-14at15:31:57	f	\N
2013-06-14 13:31:57.195262	3	f	754	81	5	ReqID-0000000081	t	\N
2013-06-14 13:31:57.195262	3	f	755	81	6	1500	t	\N
2013-06-14 13:31:57.195262	3	f	756	81	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:57.314593	3	f	757	82	1	REG-FRED_A	f	\N
2013-06-14 13:31:57.314593	3	f	758	82	2	EN	f	\N
2013-06-14 13:31:57.314593	3	f	759	82	3	passwd	f	\N
2013-06-14 13:31:57.314593	3	f	760	82	4	bupo001#13-06-14at15:31:57	f	\N
2013-06-14 13:31:57.314593	3	f	761	82	5	ReqID-0000000082	t	\N
2013-06-14 13:31:57.314593	3	f	762	82	6	1000	t	\N
2013-06-14 13:31:57.314593	3	f	763	82	7	Command completed successfully	t	\N
2013-06-14 13:31:57.367545	3	f	764	83	10	nic01.cz	f	\N
2013-06-14 13:31:57.367545	3	f	765	83	16	TESTER	f	\N
2013-06-14 13:31:57.367545	3	f	766	83	26	nssid01	f	\N
2013-06-14 13:31:57.367545	3	f	767	83	27	keyid01	f	\N
2013-06-14 13:31:57.367545	3	f	768	83	28	heslo	f	\N
2013-06-14 13:31:57.367545	3	f	769	83	54	anna	f	\N
2013-06-14 13:31:57.367545	3	f	770	83	54	TESTER	f	\N
2013-06-14 13:31:57.367545	3	f	771	83	17	3	f	\N
2013-06-14 13:31:57.367545	3	f	772	83	18	Year	f	\N
2013-06-14 13:31:57.367545	3	f	773	83	4	bupo002#13-06-14at15:31:57	f	\N
2013-06-14 13:31:57.367545	3	f	774	83	5	ReqID-0000000083	t	\N
2013-06-14 13:31:57.367545	3	f	775	83	6	1000	t	\N
2013-06-14 13:31:57.367545	3	f	776	83	7	Command completed successfully	t	\N
2013-06-14 13:31:57.367545	3	f	777	83	19	2013-06-14T15:31:57+02:00	t	\N
2013-06-14 13:31:57.497802	3	f	778	84	4	bupo003#13-06-14at15:31:57	f	\N
2013-06-14 13:31:57.497802	3	f	779	84	5	ReqID-0000000084	t	\N
2013-06-14 13:31:57.497802	3	f	780	84	6	1500	t	\N
2013-06-14 13:31:57.497802	3	f	781	84	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:57.615419	3	f	782	85	1	REG-FRED_A	f	\N
2013-06-14 13:31:57.615419	3	f	783	85	2	EN	f	\N
2013-06-14 13:31:57.615419	3	f	784	85	3	passwd	f	\N
2013-06-14 13:31:57.615419	3	f	785	85	4	usbd001#13-06-14at15:31:57	f	\N
2013-06-14 13:31:57.615419	3	f	786	85	5	ReqID-0000000085	t	\N
2013-06-14 13:31:57.615419	3	f	787	85	6	1000	t	\N
2013-06-14 13:31:57.615419	3	f	788	85	7	Command completed successfully	t	\N
2013-06-14 13:31:57.67431	3	f	789	86	10	nic02.cz	f	\N
2013-06-14 13:31:57.67431	3	f	790	86	16	TESTER	f	\N
2013-06-14 13:31:57.67431	3	f	791	86	26	nssid01	f	\N
2013-06-14 13:31:57.67431	3	f	792	86	27	keyid01	f	\N
2013-06-14 13:31:57.67431	3	f	793	86	28	heslo	f	\N
2013-06-14 13:31:57.67431	3	f	794	86	54	anna	f	\N
2013-06-14 13:31:57.67431	3	f	795	86	54	TESTER	f	\N
2013-06-14 13:31:57.67431	3	f	796	86	17	3	f	\N
2013-06-14 13:31:57.67431	3	f	797	86	18	Year	f	\N
2013-06-14 13:31:57.67431	3	f	798	86	4	usbd002#13-06-14at15:31:57	f	\N
2013-06-14 13:31:57.67431	3	f	799	86	5	ReqID-0000000086	t	\N
2013-06-14 13:31:57.67431	3	f	800	86	6	1000	t	\N
2013-06-14 13:31:57.67431	3	f	801	86	7	Command completed successfully	t	\N
2013-06-14 13:31:57.67431	3	f	802	86	19	2013-06-14T15:31:57+02:00	t	\N
2013-06-14 13:31:57.799648	3	f	803	87	4	usbd003#13-06-14at15:31:57	f	\N
2013-06-14 13:31:57.799648	3	f	804	87	5	ReqID-0000000087	t	\N
2013-06-14 13:31:57.799648	3	f	805	87	6	1500	t	\N
2013-06-14 13:31:57.799648	3	f	806	87	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:57.930438	3	f	807	88	1	REG-FRED_A	f	\N
2013-06-14 13:31:57.930438	3	f	808	88	2	EN	f	\N
2013-06-14 13:31:57.930438	3	f	809	88	3	passwd	f	\N
2013-06-14 13:31:57.930438	3	f	810	88	4	tawu001#13-06-14at15:31:57	f	\N
2013-06-14 13:31:57.930438	3	f	811	88	5	ReqID-0000000088	t	\N
2013-06-14 13:31:57.930438	3	f	812	88	6	1000	t	\N
2013-06-14 13:31:57.930438	3	f	813	88	7	Command completed successfully	t	\N
2013-06-14 13:31:57.989386	3	f	814	89	10	nic03.cz	f	\N
2013-06-14 13:31:57.989386	3	f	815	89	16	TESTER	f	\N
2013-06-14 13:31:57.989386	3	f	816	89	26	nssid01	f	\N
2013-06-14 13:31:57.989386	3	f	817	89	27	keyid01	f	\N
2013-06-14 13:31:57.989386	3	f	818	89	28	heslo	f	\N
2013-06-14 13:31:57.989386	3	f	819	89	54	anna	f	\N
2013-06-14 13:31:57.989386	3	f	820	89	54	TESTER	f	\N
2013-06-14 13:31:57.989386	3	f	821	89	17	3	f	\N
2013-06-14 13:31:57.989386	3	f	822	89	18	Year	f	\N
2013-06-14 13:31:57.989386	3	f	823	89	4	tawu002#13-06-14at15:31:57	f	\N
2013-06-14 13:31:57.989386	3	f	824	89	5	ReqID-0000000089	t	\N
2013-06-14 13:31:57.989386	3	f	825	89	6	1000	t	\N
2013-06-14 13:31:57.989386	3	f	826	89	7	Command completed successfully	t	\N
2013-06-14 13:31:57.989386	3	f	827	89	19	2013-06-14T15:31:58+02:00	t	\N
2013-06-14 13:31:58.115984	3	f	828	90	4	tawu003#13-06-14at15:31:58	f	\N
2013-06-14 13:31:58.115984	3	f	829	90	5	ReqID-0000000090	t	\N
2013-06-14 13:31:58.115984	3	f	830	90	6	1500	t	\N
2013-06-14 13:31:58.115984	3	f	831	90	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:58.249341	3	f	832	91	1	REG-FRED_A	f	\N
2013-06-14 13:31:58.249341	3	f	833	91	2	EN	f	\N
2013-06-14 13:31:58.249341	3	f	834	91	3	passwd	f	\N
2013-06-14 13:31:58.249341	3	f	835	91	4	wgrr001#13-06-14at15:31:58	f	\N
2013-06-14 13:31:58.249341	3	f	836	91	5	ReqID-0000000091	t	\N
2013-06-14 13:31:58.249341	3	f	837	91	6	1000	t	\N
2013-06-14 13:31:58.249341	3	f	838	91	7	Command completed successfully	t	\N
2013-06-14 13:31:58.308432	3	f	839	92	10	nic04.cz	f	\N
2013-06-14 13:31:58.308432	3	f	840	92	16	TESTER	f	\N
2013-06-14 13:31:58.308432	3	f	841	92	26	nssid01	f	\N
2013-06-14 13:31:58.308432	3	f	842	92	27	keyid01	f	\N
2013-06-14 13:31:58.308432	3	f	843	92	28	heslo	f	\N
2013-06-14 13:31:58.308432	3	f	844	92	54	anna	f	\N
2013-06-14 13:31:58.308432	3	f	845	92	54	TESTER	f	\N
2013-06-14 13:31:58.308432	3	f	846	92	17	3	f	\N
2013-06-14 13:31:58.308432	3	f	847	92	18	Year	f	\N
2013-06-14 13:31:58.308432	3	f	848	92	4	wgrr002#13-06-14at15:31:58	f	\N
2013-06-14 13:31:58.308432	3	f	849	92	5	ReqID-0000000092	t	\N
2013-06-14 13:31:58.308432	3	f	850	92	6	1000	t	\N
2013-06-14 13:31:58.308432	3	f	851	92	7	Command completed successfully	t	\N
2013-06-14 13:31:58.308432	3	f	852	92	19	2013-06-14T15:31:58+02:00	t	\N
2013-06-14 13:31:58.434833	3	f	853	93	4	wgrr003#13-06-14at15:31:58	f	\N
2013-06-14 13:31:58.434833	3	f	854	93	5	ReqID-0000000093	t	\N
2013-06-14 13:31:58.434833	3	f	855	93	6	1500	t	\N
2013-06-14 13:31:58.434833	3	f	856	93	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:58.557735	3	f	857	94	1	REG-FRED_A	f	\N
2013-06-14 13:31:58.557735	3	f	858	94	2	EN	f	\N
2013-06-14 13:31:58.557735	3	f	859	94	3	passwd	f	\N
2013-06-14 13:31:58.557735	3	f	860	94	4	unzb001#13-06-14at15:31:58	f	\N
2013-06-14 13:31:58.557735	3	f	861	94	5	ReqID-0000000094	t	\N
2013-06-14 13:31:58.557735	3	f	862	94	6	1000	t	\N
2013-06-14 13:31:58.557735	3	f	863	94	7	Command completed successfully	t	\N
2013-06-14 13:31:58.621642	3	f	864	95	10	nic05.cz	f	\N
2013-06-14 13:31:58.621642	3	f	865	95	16	TESTER	f	\N
2013-06-14 13:31:58.621642	3	f	866	95	26	nssid01	f	\N
2013-06-14 13:31:58.621642	3	f	867	95	27	keyid01	f	\N
2013-06-14 13:31:58.621642	3	f	868	95	28	heslo	f	\N
2013-06-14 13:31:58.621642	3	f	869	95	54	anna	f	\N
2013-06-14 13:31:58.621642	3	f	870	95	54	TESTER	f	\N
2013-06-14 13:31:58.621642	3	f	871	95	17	3	f	\N
2013-06-14 13:31:58.621642	3	f	872	95	18	Year	f	\N
2013-06-14 13:31:58.621642	3	f	873	95	4	unzb002#13-06-14at15:31:58	f	\N
2013-06-14 13:31:58.621642	3	f	874	95	5	ReqID-0000000095	t	\N
2013-06-14 13:31:58.621642	3	f	875	95	6	1000	t	\N
2013-06-14 13:31:58.621642	3	f	876	95	7	Command completed successfully	t	\N
2013-06-14 13:31:58.621642	3	f	877	95	19	2013-06-14T15:31:58+02:00	t	\N
2013-06-14 13:31:58.747057	3	f	878	96	4	unzb003#13-06-14at15:31:58	f	\N
2013-06-14 13:31:58.747057	3	f	879	96	5	ReqID-0000000096	t	\N
2013-06-14 13:31:58.747057	3	f	880	96	6	1500	t	\N
2013-06-14 13:31:58.747057	3	f	881	96	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:58.868199	3	f	882	97	1	REG-FRED_A	f	\N
2013-06-14 13:31:58.868199	3	f	883	97	2	EN	f	\N
2013-06-14 13:31:58.868199	3	f	884	97	3	passwd	f	\N
2013-06-14 13:31:58.868199	3	f	885	97	4	rgwq001#13-06-14at15:31:58	f	\N
2013-06-14 13:31:58.868199	3	f	886	97	5	ReqID-0000000097	t	\N
2013-06-14 13:31:58.868199	3	f	887	97	6	1000	t	\N
2013-06-14 13:31:58.868199	3	f	888	97	7	Command completed successfully	t	\N
2013-06-14 13:31:58.927217	3	f	889	98	10	nic06.cz	f	\N
2013-06-14 13:31:58.927217	3	f	890	98	16	TESTER	f	\N
2013-06-14 13:31:58.927217	3	f	891	98	26	nssid01	f	\N
2013-06-14 13:31:58.927217	3	f	892	98	27	keyid01	f	\N
2013-06-14 13:31:58.927217	3	f	893	98	28	heslo	f	\N
2013-06-14 13:31:58.927217	3	f	894	98	54	anna	f	\N
2013-06-14 13:31:58.927217	3	f	895	98	54	TESTER	f	\N
2013-06-14 13:31:58.927217	3	f	896	98	17	3	f	\N
2013-06-14 13:31:58.927217	3	f	897	98	18	Year	f	\N
2013-06-14 13:31:58.927217	3	f	898	98	4	rgwq002#13-06-14at15:31:58	f	\N
2013-06-14 13:31:58.927217	3	f	899	98	5	ReqID-0000000098	t	\N
2013-06-14 13:31:58.927217	3	f	900	98	6	1000	t	\N
2013-06-14 13:31:58.927217	3	f	901	98	7	Command completed successfully	t	\N
2013-06-14 13:31:58.927217	3	f	902	98	19	2013-06-14T15:31:58+02:00	t	\N
2013-06-14 13:31:59.055859	3	f	903	99	4	rgwq003#13-06-14at15:31:59	f	\N
2013-06-14 13:31:59.055859	3	f	904	99	5	ReqID-0000000099	t	\N
2013-06-14 13:31:59.055859	3	f	905	99	6	1500	t	\N
2013-06-14 13:31:59.055859	3	f	906	99	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:59.178127	3	f	907	100	1	REG-FRED_A	f	\N
2013-06-14 13:31:59.178127	3	f	908	100	2	EN	f	\N
2013-06-14 13:31:59.178127	3	f	909	100	3	passwd	f	\N
2013-06-14 13:31:59.178127	3	f	910	100	4	cywy001#13-06-14at15:31:59	f	\N
2013-06-14 13:31:59.178127	3	f	911	100	5	ReqID-0000000100	t	\N
2013-06-14 13:31:59.178127	3	f	912	100	6	1000	t	\N
2013-06-14 13:31:59.178127	3	f	913	100	7	Command completed successfully	t	\N
2013-06-14 13:31:59.237565	3	f	914	101	10	nic07.cz	f	\N
2013-06-14 13:31:59.237565	3	f	915	101	16	TESTER	f	\N
2013-06-14 13:31:59.237565	3	f	916	101	26	nssid01	f	\N
2013-06-14 13:31:59.237565	3	f	917	101	27	keyid01	f	\N
2013-06-14 13:31:59.237565	3	f	918	101	28	heslo	f	\N
2013-06-14 13:31:59.237565	3	f	919	101	54	anna	f	\N
2013-06-14 13:31:59.237565	3	f	920	101	54	TESTER	f	\N
2013-06-14 13:31:59.237565	3	f	921	101	17	3	f	\N
2013-06-14 13:31:59.237565	3	f	922	101	18	Year	f	\N
2013-06-14 13:31:59.237565	3	f	923	101	4	cywy002#13-06-14at15:31:59	f	\N
2013-06-14 13:31:59.237565	3	f	924	101	5	ReqID-0000000101	t	\N
2013-06-14 13:31:59.237565	3	f	925	101	6	1000	t	\N
2013-06-14 13:31:59.237565	3	f	926	101	7	Command completed successfully	t	\N
2013-06-14 13:31:59.237565	3	f	927	101	19	2013-06-14T15:31:59+02:00	t	\N
2013-06-14 13:31:59.364126	3	f	928	102	4	cywy003#13-06-14at15:31:59	f	\N
2013-06-14 13:31:59.364126	3	f	929	102	5	ReqID-0000000102	t	\N
2013-06-14 13:31:59.364126	3	f	930	102	6	1500	t	\N
2013-06-14 13:31:59.364126	3	f	931	102	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:59.488069	3	f	932	103	1	REG-FRED_A	f	\N
2013-06-14 13:31:59.488069	3	f	933	103	2	EN	f	\N
2013-06-14 13:31:59.488069	3	f	934	103	3	passwd	f	\N
2013-06-14 13:31:59.488069	3	f	935	103	4	rcfx001#13-06-14at15:31:59	f	\N
2013-06-14 13:31:59.488069	3	f	936	103	5	ReqID-0000000103	t	\N
2013-06-14 13:31:59.488069	3	f	937	103	6	1000	t	\N
2013-06-14 13:31:59.488069	3	f	938	103	7	Command completed successfully	t	\N
2013-06-14 13:31:59.54742	3	f	939	104	10	nic08.cz	f	\N
2013-06-14 13:31:59.54742	3	f	940	104	16	TESTER	f	\N
2013-06-14 13:31:59.54742	3	f	941	104	26	nssid01	f	\N
2013-06-14 13:31:59.54742	3	f	942	104	27	keyid01	f	\N
2013-06-14 13:31:59.54742	3	f	943	104	28	heslo	f	\N
2013-06-14 13:31:59.54742	3	f	944	104	54	anna	f	\N
2013-06-14 13:31:59.54742	3	f	945	104	54	TESTER	f	\N
2013-06-14 13:31:59.54742	3	f	946	104	17	3	f	\N
2013-06-14 13:31:59.54742	3	f	947	104	18	Year	f	\N
2013-06-14 13:31:59.54742	3	f	948	104	4	rcfx002#13-06-14at15:31:59	f	\N
2013-06-14 13:31:59.54742	3	f	949	104	5	ReqID-0000000104	t	\N
2013-06-14 13:31:59.54742	3	f	950	104	6	1000	t	\N
2013-06-14 13:31:59.54742	3	f	951	104	7	Command completed successfully	t	\N
2013-06-14 13:31:59.54742	3	f	952	104	19	2013-06-14T15:31:59+02:00	t	\N
2013-06-14 13:31:59.678123	3	f	953	105	4	rcfx003#13-06-14at15:31:59	f	\N
2013-06-14 13:31:59.678123	3	f	954	105	5	ReqID-0000000105	t	\N
2013-06-14 13:31:59.678123	3	f	955	105	6	1500	t	\N
2013-06-14 13:31:59.678123	3	f	956	105	7	Command completed successfully; ending session	t	\N
2013-06-14 13:31:59.799385	3	f	957	106	1	REG-FRED_A	f	\N
2013-06-14 13:31:59.799385	3	f	958	106	2	EN	f	\N
2013-06-14 13:31:59.799385	3	f	959	106	3	passwd	f	\N
2013-06-14 13:31:59.799385	3	f	960	106	4	gyxz001#13-06-14at15:31:59	f	\N
2013-06-14 13:31:59.799385	3	f	961	106	5	ReqID-0000000106	t	\N
2013-06-14 13:31:59.799385	3	f	962	106	6	1000	t	\N
2013-06-14 13:31:59.799385	3	f	963	106	7	Command completed successfully	t	\N
2013-06-14 13:31:59.858572	3	f	964	107	10	nic09.cz	f	\N
2013-06-14 13:31:59.858572	3	f	965	107	16	TESTER	f	\N
2013-06-14 13:31:59.858572	3	f	966	107	26	nssid01	f	\N
2013-06-14 13:31:59.858572	3	f	967	107	27	keyid01	f	\N
2013-06-14 13:31:59.858572	3	f	968	107	28	heslo	f	\N
2013-06-14 13:31:59.858572	3	f	969	107	54	anna	f	\N
2013-06-14 13:31:59.858572	3	f	970	107	54	TESTER	f	\N
2013-06-14 13:31:59.858572	3	f	971	107	17	3	f	\N
2013-06-14 13:31:59.858572	3	f	972	107	18	Year	f	\N
2013-06-14 13:31:59.858572	3	f	973	107	4	gyxz002#13-06-14at15:31:59	f	\N
2013-06-14 13:31:59.858572	3	f	974	107	5	ReqID-0000000107	t	\N
2013-06-14 13:31:59.858572	3	f	975	107	6	1000	t	\N
2013-06-14 13:31:59.858572	3	f	976	107	7	Command completed successfully	t	\N
2013-06-14 13:31:59.858572	3	f	977	107	19	2013-06-14T15:31:59+02:00	t	\N
2013-06-14 13:31:59.984729	3	f	978	108	4	gyxz003#13-06-14at15:31:59	f	\N
2013-06-14 13:31:59.984729	3	f	979	108	5	ReqID-0000000108	t	\N
2013-06-14 13:31:59.984729	3	f	980	108	6	1500	t	\N
2013-06-14 13:31:59.984729	3	f	981	108	7	Command completed successfully; ending session	t	\N
2013-06-14 13:32:00.10372	3	f	982	109	1	REG-FRED_A	f	\N
2013-06-14 13:32:00.10372	3	f	983	109	2	EN	f	\N
2013-06-14 13:32:00.10372	3	f	984	109	3	passwd	f	\N
2013-06-14 13:32:00.10372	3	f	985	109	4	bfhp001#13-06-14at15:32:00	f	\N
2013-06-14 13:32:00.10372	3	f	986	109	5	ReqID-0000000109	t	\N
2013-06-14 13:32:00.10372	3	f	987	109	6	1000	t	\N
2013-06-14 13:32:00.10372	3	f	988	109	7	Command completed successfully	t	\N
2013-06-14 13:32:00.163381	3	f	989	110	10	nic10.cz	f	\N
2013-06-14 13:32:00.163381	3	f	990	110	16	TESTER	f	\N
2013-06-14 13:32:00.163381	3	f	991	110	26	nssid01	f	\N
2013-06-14 13:32:00.163381	3	f	992	110	27	keyid01	f	\N
2013-06-14 13:32:00.163381	3	f	993	110	28	heslo	f	\N
2013-06-14 13:32:00.163381	3	f	994	110	54	anna	f	\N
2013-06-14 13:32:00.163381	3	f	995	110	54	TESTER	f	\N
2013-06-14 13:32:00.163381	3	f	996	110	17	3	f	\N
2013-06-14 13:32:00.163381	3	f	997	110	18	Year	f	\N
2013-06-14 13:32:00.163381	3	f	998	110	4	bfhp002#13-06-14at15:32:00	f	\N
2013-06-14 13:32:00.163381	3	f	999	110	5	ReqID-0000000110	t	\N
2013-06-14 13:32:00.163381	3	f	1000	110	6	1000	t	\N
2013-06-14 13:32:00.163381	3	f	1001	110	7	Command completed successfully	t	\N
2013-06-14 13:32:00.163381	3	f	1002	110	19	2013-06-14T15:32:00+02:00	t	\N
2013-06-14 13:32:00.290621	3	f	1003	111	4	bfhp003#13-06-14at15:32:00	f	\N
2013-06-14 13:32:00.290621	3	f	1004	111	5	ReqID-0000000111	t	\N
2013-06-14 13:32:00.290621	3	f	1005	111	6	1500	t	\N
2013-06-14 13:32:00.290621	3	f	1006	111	7	Command completed successfully; ending session	t	\N
2013-06-14 13:32:00.411361	3	f	1007	112	1	REG-FRED_A	f	\N
2013-06-14 13:32:00.411361	3	f	1008	112	2	EN	f	\N
2013-06-14 13:32:00.411361	3	f	1009	112	3	passwd	f	\N
2013-06-14 13:32:00.411361	3	f	1010	112	4	cpbg001#13-06-14at15:32:00	f	\N
2013-06-14 13:32:00.411361	3	f	1011	112	5	ReqID-0000000112	t	\N
2013-06-14 13:32:00.411361	3	f	1012	112	6	1000	t	\N
2013-06-14 13:32:00.411361	3	f	1013	112	7	Command completed successfully	t	\N
2013-06-14 13:32:00.470148	3	f	1014	113	10	ginger01.cz	f	\N
2013-06-14 13:32:00.470148	3	f	1015	113	16	anna	f	\N
2013-06-14 13:32:00.470148	3	f	1016	113	26	nssid01	f	\N
2013-06-14 13:32:00.470148	3	f	1017	113	27	keyid01	f	\N
2013-06-14 13:32:00.470148	3	f	1018	113	28	heslo	f	\N
2013-06-14 13:32:00.470148	3	f	1019	113	54	TESTER	f	\N
2013-06-14 13:32:00.470148	3	f	1020	113	17	3	f	\N
2013-06-14 13:32:00.470148	3	f	1021	113	18	Year	f	\N
2013-06-14 13:32:00.470148	3	f	1022	113	4	cpbg002#13-06-14at15:32:00	f	\N
2013-06-14 13:32:00.470148	3	f	1023	113	5	ReqID-0000000113	t	\N
2013-06-14 13:32:00.470148	3	f	1024	113	6	1000	t	\N
2013-06-14 13:32:00.470148	3	f	1025	113	7	Command completed successfully	t	\N
2013-06-14 13:32:00.470148	3	f	1026	113	19	2013-06-14T15:32:00+02:00	t	\N
2013-06-14 13:32:00.590745	3	f	1027	114	4	cpbg003#13-06-14at15:32:00	f	\N
2013-06-14 13:32:00.590745	3	f	1028	114	5	ReqID-0000000114	t	\N
2013-06-14 13:32:00.590745	3	f	1029	114	6	1500	t	\N
2013-06-14 13:32:00.590745	3	f	1030	114	7	Command completed successfully; ending session	t	\N
2013-06-14 13:32:00.710188	3	f	1031	115	1	REG-FRED_A	f	\N
2013-06-14 13:32:00.710188	3	f	1032	115	2	EN	f	\N
2013-06-14 13:32:00.710188	3	f	1033	115	3	passwd	f	\N
2013-06-14 13:32:00.710188	3	f	1034	115	4	aknx001#13-06-14at15:32:00	f	\N
2013-06-14 13:32:00.710188	3	f	1035	115	5	ReqID-0000000115	t	\N
2013-06-14 13:32:00.710188	3	f	1036	115	6	1000	t	\N
2013-06-14 13:32:00.710188	3	f	1037	115	7	Command completed successfully	t	\N
2013-06-14 13:32:00.76986	3	f	1038	116	10	ginger02.cz	f	\N
2013-06-14 13:32:00.76986	3	f	1039	116	16	anna	f	\N
2013-06-14 13:32:00.76986	3	f	1040	116	26	nssid01	f	\N
2013-06-14 13:32:00.76986	3	f	1041	116	27	keyid01	f	\N
2013-06-14 13:32:00.76986	3	f	1042	116	28	heslo	f	\N
2013-06-14 13:32:00.76986	3	f	1043	116	54	TESTER	f	\N
2013-06-14 13:32:00.76986	3	f	1044	116	17	3	f	\N
2013-06-14 13:32:00.76986	3	f	1045	116	18	Year	f	\N
2013-06-14 13:32:00.76986	3	f	1046	116	4	aknx002#13-06-14at15:32:00	f	\N
2013-06-14 13:32:00.76986	3	f	1047	116	5	ReqID-0000000116	t	\N
2013-06-14 13:32:00.76986	3	f	1048	116	6	1000	t	\N
2013-06-14 13:32:00.76986	3	f	1049	116	7	Command completed successfully	t	\N
2013-06-14 13:32:00.76986	3	f	1050	116	19	2013-06-14T15:32:00+02:00	t	\N
2013-06-14 13:32:00.89147	3	f	1051	117	4	aknx003#13-06-14at15:32:00	f	\N
2013-06-14 13:32:00.89147	3	f	1052	117	5	ReqID-0000000117	t	\N
2013-06-14 13:32:00.89147	3	f	1053	117	6	1500	t	\N
2013-06-14 13:32:00.89147	3	f	1054	117	7	Command completed successfully; ending session	t	\N
2013-06-14 13:32:01.015982	3	f	1055	118	1	REG-FRED_A	f	\N
2013-06-14 13:32:01.015982	3	f	1056	118	2	EN	f	\N
2013-06-14 13:32:01.015982	3	f	1057	118	3	passwd	f	\N
2013-06-14 13:32:01.015982	3	f	1058	118	4	trta001#13-06-14at15:32:01	f	\N
2013-06-14 13:32:01.015982	3	f	1059	118	5	ReqID-0000000118	t	\N
2013-06-14 13:32:01.015982	3	f	1060	118	6	1000	t	\N
2013-06-14 13:32:01.015982	3	f	1061	118	7	Command completed successfully	t	\N
2013-06-14 13:32:01.07493	3	f	1062	119	10	ginger03.cz	f	\N
2013-06-14 13:32:01.07493	3	f	1063	119	16	anna	f	\N
2013-06-14 13:32:01.07493	3	f	1064	119	26	nssid01	f	\N
2013-06-14 13:32:01.07493	3	f	1065	119	27	keyid01	f	\N
2013-06-14 13:32:01.07493	3	f	1066	119	28	heslo	f	\N
2013-06-14 13:32:01.07493	3	f	1067	119	54	TESTER	f	\N
2013-06-14 13:32:01.07493	3	f	1068	119	17	3	f	\N
2013-06-14 13:32:01.07493	3	f	1069	119	18	Year	f	\N
2013-06-14 13:32:01.07493	3	f	1070	119	4	trta002#13-06-14at15:32:01	f	\N
2013-06-14 13:32:01.07493	3	f	1071	119	5	ReqID-0000000119	t	\N
2013-06-14 13:32:01.07493	3	f	1072	119	6	1000	t	\N
2013-06-14 13:32:01.07493	3	f	1073	119	7	Command completed successfully	t	\N
2013-06-14 13:32:01.07493	3	f	1074	119	19	2013-06-14T15:32:01+02:00	t	\N
2013-06-14 13:32:01.196397	3	f	1075	120	4	trta003#13-06-14at15:32:01	f	\N
2013-06-14 13:32:01.196397	3	f	1076	120	5	ReqID-0000000120	t	\N
2013-06-14 13:32:01.196397	3	f	1077	120	6	1500	t	\N
2013-06-14 13:32:01.196397	3	f	1078	120	7	Command completed successfully; ending session	t	\N
2013-06-14 13:32:01.328519	3	f	1079	121	1	REG-FRED_A	f	\N
2013-06-14 13:32:01.328519	3	f	1080	121	2	EN	f	\N
2013-06-14 13:32:01.328519	3	f	1081	121	3	passwd	f	\N
2013-06-14 13:32:01.328519	3	f	1082	121	4	djmf001#13-06-14at15:32:01	f	\N
2013-06-14 13:32:01.328519	3	f	1083	121	5	ReqID-0000000121	t	\N
2013-06-14 13:32:01.328519	3	f	1084	121	6	1000	t	\N
2013-06-14 13:32:01.328519	3	f	1085	121	7	Command completed successfully	t	\N
2013-06-14 13:32:01.387742	3	f	1086	122	10	ginger04.cz	f	\N
2013-06-14 13:32:01.387742	3	f	1087	122	16	anna	f	\N
2013-06-14 13:32:01.387742	3	f	1088	122	26	nssid01	f	\N
2013-06-14 13:32:01.387742	3	f	1089	122	27	keyid01	f	\N
2013-06-14 13:32:01.387742	3	f	1090	122	28	heslo	f	\N
2013-06-14 13:32:01.387742	3	f	1091	122	54	TESTER	f	\N
2013-06-14 13:32:01.387742	3	f	1092	122	17	3	f	\N
2013-06-14 13:32:01.387742	3	f	1093	122	18	Year	f	\N
2013-06-14 13:32:01.387742	3	f	1094	122	4	djmf002#13-06-14at15:32:01	f	\N
2013-06-14 13:32:01.387742	3	f	1095	122	5	ReqID-0000000122	t	\N
2013-06-14 13:32:01.387742	3	f	1096	122	6	1000	t	\N
2013-06-14 13:32:01.387742	3	f	1097	122	7	Command completed successfully	t	\N
2013-06-14 13:32:01.387742	3	f	1098	122	19	2013-06-14T15:32:01+02:00	t	\N
2013-06-14 13:32:01.509354	3	f	1099	123	4	djmf003#13-06-14at15:32:01	f	\N
2013-06-14 13:32:01.509354	3	f	1100	123	5	ReqID-0000000123	t	\N
2013-06-14 13:32:01.509354	3	f	1101	123	6	1500	t	\N
2013-06-14 13:32:01.509354	3	f	1102	123	7	Command completed successfully; ending session	t	\N
2013-06-14 13:32:01.638268	3	f	1103	124	1	REG-FRED_A	f	\N
2013-06-14 13:32:01.638268	3	f	1104	124	2	EN	f	\N
2013-06-14 13:32:01.638268	3	f	1105	124	3	passwd	f	\N
2013-06-14 13:32:01.638268	3	f	1106	124	4	dccy001#13-06-14at15:32:01	f	\N
2013-06-14 13:32:01.638268	3	f	1107	124	5	ReqID-0000000124	t	\N
2013-06-14 13:32:01.638268	3	f	1108	124	6	1000	t	\N
2013-06-14 13:32:01.638268	3	f	1109	124	7	Command completed successfully	t	\N
2013-06-14 13:32:01.69753	3	f	1110	125	10	ginger05.cz	f	\N
2013-06-14 13:32:01.69753	3	f	1111	125	16	anna	f	\N
2013-06-14 13:32:01.69753	3	f	1112	125	26	nssid01	f	\N
2013-06-14 13:32:01.69753	3	f	1113	125	27	keyid01	f	\N
2013-06-14 13:32:01.69753	3	f	1114	125	28	heslo	f	\N
2013-06-14 13:32:01.69753	3	f	1115	125	54	TESTER	f	\N
2013-06-14 13:32:01.69753	3	f	1116	125	17	3	f	\N
2013-06-14 13:32:01.69753	3	f	1117	125	18	Year	f	\N
2013-06-14 13:32:01.69753	3	f	1118	125	4	dccy002#13-06-14at15:32:01	f	\N
2013-06-14 13:32:01.69753	3	f	1119	125	5	ReqID-0000000125	t	\N
2013-06-14 13:32:01.69753	3	f	1120	125	6	1000	t	\N
2013-06-14 13:32:01.69753	3	f	1121	125	7	Command completed successfully	t	\N
2013-06-14 13:32:01.69753	3	f	1122	125	19	2013-06-14T15:32:01+02:00	t	\N
2013-06-14 13:32:01.819018	3	f	1123	126	4	dccy003#13-06-14at15:32:01	f	\N
2013-06-14 13:32:01.819018	3	f	1124	126	5	ReqID-0000000126	t	\N
2013-06-14 13:32:01.819018	3	f	1125	126	6	1500	t	\N
2013-06-14 13:32:01.819018	3	f	1126	126	7	Command completed successfully; ending session	t	\N
2013-06-14 13:32:01.958009	3	f	1127	127	1	REG-FRED_A	f	\N
2013-06-14 13:32:01.958009	3	f	1128	127	2	EN	f	\N
2013-06-14 13:32:01.958009	3	f	1129	127	3	passwd	f	\N
2013-06-14 13:32:01.958009	3	f	1130	127	4	cwdf001#13-06-14at15:32:01	f	\N
2013-06-14 13:32:01.958009	3	f	1131	127	5	ReqID-0000000127	t	\N
2013-06-14 13:32:01.958009	3	f	1132	127	6	1000	t	\N
2013-06-14 13:32:01.958009	3	f	1133	127	7	Command completed successfully	t	\N
2013-06-14 13:32:02.01731	3	f	1134	128	10	ginger06.cz	f	\N
2013-06-14 13:32:02.01731	3	f	1135	128	16	anna	f	\N
2013-06-14 13:32:02.01731	3	f	1136	128	26	nssid01	f	\N
2013-06-14 13:32:02.01731	3	f	1137	128	27	keyid01	f	\N
2013-06-14 13:32:02.01731	3	f	1138	128	28	heslo	f	\N
2013-06-14 13:32:02.01731	3	f	1139	128	54	TESTER	f	\N
2013-06-14 13:32:02.01731	3	f	1140	128	17	3	f	\N
2013-06-14 13:32:02.01731	3	f	1141	128	18	Year	f	\N
2013-06-14 13:32:02.01731	3	f	1142	128	4	cwdf002#13-06-14at15:32:02	f	\N
2013-06-14 13:32:02.01731	3	f	1143	128	5	ReqID-0000000128	t	\N
2013-06-14 13:32:02.01731	3	f	1144	128	6	1000	t	\N
2013-06-14 13:32:02.01731	3	f	1145	128	7	Command completed successfully	t	\N
2013-06-14 13:32:02.01731	3	f	1146	128	19	2013-06-14T15:32:02+02:00	t	\N
2013-06-14 13:32:02.140865	3	f	1147	129	4	cwdf003#13-06-14at15:32:02	f	\N
2013-06-14 13:32:02.140865	3	f	1148	129	5	ReqID-0000000129	t	\N
2013-06-14 13:32:02.140865	3	f	1149	129	6	1500	t	\N
2013-06-14 13:32:02.140865	3	f	1150	129	7	Command completed successfully; ending session	t	\N
2013-06-14 13:32:02.260969	3	f	1151	130	1	REG-FRED_A	f	\N
2013-06-14 13:32:02.260969	3	f	1152	130	2	EN	f	\N
2013-06-14 13:32:02.260969	3	f	1153	130	3	passwd	f	\N
2013-06-14 13:32:02.260969	3	f	1154	130	4	gzpq001#13-06-14at15:32:02	f	\N
2013-06-14 13:32:02.260969	3	f	1155	130	5	ReqID-0000000130	t	\N
2013-06-14 13:32:02.260969	3	f	1156	130	6	1000	t	\N
2013-06-14 13:32:02.260969	3	f	1157	130	7	Command completed successfully	t	\N
2013-06-14 13:32:02.321543	3	f	1158	131	10	ginger07.cz	f	\N
2013-06-14 13:32:02.321543	3	f	1159	131	16	anna	f	\N
2013-06-14 13:32:02.321543	3	f	1160	131	26	nssid01	f	\N
2013-06-14 13:32:02.321543	3	f	1161	131	27	keyid01	f	\N
2013-06-14 13:32:02.321543	3	f	1162	131	28	heslo	f	\N
2013-06-14 13:32:02.321543	3	f	1163	131	54	TESTER	f	\N
2013-06-14 13:32:02.321543	3	f	1164	131	17	3	f	\N
2013-06-14 13:32:02.321543	3	f	1165	131	18	Year	f	\N
2013-06-14 13:32:02.321543	3	f	1166	131	4	gzpq002#13-06-14at15:32:02	f	\N
2013-06-14 13:32:02.321543	3	f	1167	131	5	ReqID-0000000131	t	\N
2013-06-14 13:32:02.321543	3	f	1168	131	6	1000	t	\N
2013-06-14 13:32:02.321543	3	f	1169	131	7	Command completed successfully	t	\N
2013-06-14 13:32:02.321543	3	f	1170	131	19	2013-06-14T15:32:02+02:00	t	\N
2013-06-14 13:32:02.442676	3	f	1171	132	4	gzpq003#13-06-14at15:32:02	f	\N
2013-06-14 13:32:02.442676	3	f	1172	132	5	ReqID-0000000132	t	\N
2013-06-14 13:32:02.442676	3	f	1173	132	6	1500	t	\N
2013-06-14 13:32:02.442676	3	f	1174	132	7	Command completed successfully; ending session	t	\N
2013-06-14 13:32:02.566777	3	f	1175	133	1	REG-FRED_A	f	\N
2013-06-14 13:32:02.566777	3	f	1176	133	2	EN	f	\N
2013-06-14 13:32:02.566777	3	f	1177	133	3	passwd	f	\N
2013-06-14 13:32:02.566777	3	f	1178	133	4	cepx001#13-06-14at15:32:02	f	\N
2013-06-14 13:32:02.566777	3	f	1179	133	5	ReqID-0000000133	t	\N
2013-06-14 13:32:02.566777	3	f	1180	133	6	1000	t	\N
2013-06-14 13:32:02.566777	3	f	1181	133	7	Command completed successfully	t	\N
2013-06-14 13:32:02.626066	3	f	1182	134	10	ginger08.cz	f	\N
2013-06-14 13:32:02.626066	3	f	1183	134	16	anna	f	\N
2013-06-14 13:32:02.626066	3	f	1184	134	26	nssid01	f	\N
2013-06-14 13:32:02.626066	3	f	1185	134	27	keyid01	f	\N
2013-06-14 13:32:02.626066	3	f	1186	134	28	heslo	f	\N
2013-06-14 13:32:02.626066	3	f	1187	134	54	TESTER	f	\N
2013-06-14 13:32:02.626066	3	f	1188	134	17	3	f	\N
2013-06-14 13:32:02.626066	3	f	1189	134	18	Year	f	\N
2013-06-14 13:32:02.626066	3	f	1190	134	4	cepx002#13-06-14at15:32:02	f	\N
2013-06-14 13:32:02.626066	3	f	1191	134	5	ReqID-0000000134	t	\N
2013-06-14 13:32:02.626066	3	f	1192	134	6	1000	t	\N
2013-06-14 13:32:02.626066	3	f	1193	134	7	Command completed successfully	t	\N
2013-06-14 13:32:02.626066	3	f	1194	134	19	2013-06-14T15:32:02+02:00	t	\N
2013-06-14 13:32:02.747333	3	f	1195	135	4	cepx003#13-06-14at15:32:02	f	\N
2013-06-14 13:32:02.747333	3	f	1196	135	5	ReqID-0000000135	t	\N
2013-06-14 13:32:02.747333	3	f	1197	135	6	1500	t	\N
2013-06-14 13:32:02.747333	3	f	1198	135	7	Command completed successfully; ending session	t	\N
2013-06-14 13:32:02.868341	3	f	1199	136	1	REG-FRED_A	f	\N
2013-06-14 13:32:02.868341	3	f	1200	136	2	EN	f	\N
2013-06-14 13:32:02.868341	3	f	1201	136	3	passwd	f	\N
2013-06-14 13:32:02.868341	3	f	1202	136	4	zcru001#13-06-14at15:32:02	f	\N
2013-06-14 13:32:02.868341	3	f	1203	136	5	ReqID-0000000136	t	\N
2013-06-14 13:32:02.868341	3	f	1204	136	6	1000	t	\N
2013-06-14 13:32:02.868341	3	f	1205	136	7	Command completed successfully	t	\N
2013-06-14 13:32:02.928105	3	f	1206	137	10	ginger09.cz	f	\N
2013-06-14 13:32:02.928105	3	f	1207	137	16	anna	f	\N
2013-06-14 13:32:02.928105	3	f	1208	137	26	nssid01	f	\N
2013-06-14 13:32:02.928105	3	f	1209	137	27	keyid01	f	\N
2013-06-14 13:32:02.928105	3	f	1210	137	28	heslo	f	\N
2013-06-14 13:32:02.928105	3	f	1211	137	54	TESTER	f	\N
2013-06-14 13:32:02.928105	3	f	1212	137	17	3	f	\N
2013-06-14 13:32:02.928105	3	f	1213	137	18	Year	f	\N
2013-06-14 13:32:02.928105	3	f	1214	137	4	zcru002#13-06-14at15:32:02	f	\N
2013-06-14 13:32:02.928105	3	f	1215	137	5	ReqID-0000000137	t	\N
2013-06-14 13:32:02.928105	3	f	1216	137	6	1000	t	\N
2013-06-14 13:32:02.928105	3	f	1217	137	7	Command completed successfully	t	\N
2013-06-14 13:32:02.928105	3	f	1218	137	19	2013-06-14T15:32:02+02:00	t	\N
2013-06-14 13:32:03.050358	3	f	1219	138	4	zcru003#13-06-14at15:32:03	f	\N
2013-06-14 13:32:03.050358	3	f	1220	138	5	ReqID-0000000138	t	\N
2013-06-14 13:32:03.050358	3	f	1221	138	6	1500	t	\N
2013-06-14 13:32:03.050358	3	f	1222	138	7	Command completed successfully; ending session	t	\N
2013-06-14 13:32:03.164551	3	f	1223	139	1	REG-FRED_A	f	\N
2013-06-14 13:32:03.164551	3	f	1224	139	2	EN	f	\N
2013-06-14 13:32:03.164551	3	f	1225	139	3	passwd	f	\N
2013-06-14 13:32:03.164551	3	f	1226	139	4	rpro001#13-06-14at15:32:03	f	\N
2013-06-14 13:32:03.164551	3	f	1227	139	5	ReqID-0000000139	t	\N
2013-06-14 13:32:03.164551	3	f	1228	139	6	1000	t	\N
2013-06-14 13:32:03.164551	3	f	1229	139	7	Command completed successfully	t	\N
2013-06-14 13:32:03.223592	3	f	1230	140	10	ginger10.cz	f	\N
2013-06-14 13:32:03.223592	3	f	1231	140	16	anna	f	\N
2013-06-14 13:32:03.223592	3	f	1232	140	26	nssid01	f	\N
2013-06-14 13:32:03.223592	3	f	1233	140	27	keyid01	f	\N
2013-06-14 13:32:03.223592	3	f	1234	140	28	heslo	f	\N
2013-06-14 13:32:03.223592	3	f	1235	140	54	TESTER	f	\N
2013-06-14 13:32:03.223592	3	f	1236	140	17	3	f	\N
2013-06-14 13:32:03.223592	3	f	1237	140	18	Year	f	\N
2013-06-14 13:32:03.223592	3	f	1238	140	4	rpro002#13-06-14at15:32:03	f	\N
2013-06-14 13:32:03.223592	3	f	1239	140	5	ReqID-0000000140	t	\N
2013-06-14 13:32:03.223592	3	f	1240	140	6	1000	t	\N
2013-06-14 13:32:03.223592	3	f	1241	140	7	Command completed successfully	t	\N
2013-06-14 13:32:03.223592	3	f	1242	140	19	2013-06-14T15:32:03+02:00	t	\N
2013-06-14 13:32:03.344442	3	f	1243	141	4	rpro003#13-06-14at15:32:03	f	\N
2013-06-14 13:32:03.344442	3	f	1244	141	5	ReqID-0000000141	t	\N
2013-06-14 13:32:03.344442	3	f	1245	141	6	1500	t	\N
2013-06-14 13:32:03.344442	3	f	1246	141	7	Command completed successfully; ending session	t	\N
2013-06-14 13:32:03.470343	3	f	1247	142	1	REG-FRED_A	f	\N
2013-06-14 13:32:03.470343	3	f	1248	142	2	EN	f	\N
2013-06-14 13:32:03.470343	3	f	1249	142	3	passwd	f	\N
2013-06-14 13:32:03.470343	3	f	1250	142	4	ysvi001#13-06-14at15:32:03	f	\N
2013-06-14 13:32:03.470343	3	f	1251	142	5	ReqID-0000000142	t	\N
2013-06-14 13:32:03.470343	3	f	1252	142	6	1000	t	\N
2013-06-14 13:32:03.470343	3	f	1253	142	7	Command completed successfully	t	\N
2013-06-14 13:32:03.529912	3	f	1254	143	10	1.1.1.8.4.5.2.2.2.0.2.4.e164.arpa	f	\N
2013-06-14 13:32:03.529912	3	f	1255	143	16	TESTER	f	\N
2013-06-14 13:32:03.529912	3	f	1256	143	26	nssid01	f	\N
2013-06-14 13:32:03.529912	3	f	1257	143	27	keyid01	f	\N
2013-06-14 13:32:03.529912	3	f	1258	143	54	anna	f	\N
2013-06-14 13:32:03.529912	3	f	1259	143	54	bob	f	\N
2013-06-14 13:32:03.529912	3	f	1260	143	17	0	f	\N
2013-06-14 13:32:03.529912	3	f	1261	143	18	Month	f	\N
2013-06-14 13:32:03.529912	3	f	1262	143	4	ysvi002#13-06-14at15:32:03	f	\N
2013-06-14 13:32:03.529912	3	f	1263	143	5	ReqID-0000000143	t	\N
2013-06-14 13:32:03.529912	3	f	1264	143	6	1000	t	\N
2013-06-14 13:32:03.529912	3	f	1265	143	7	Command completed successfully	t	\N
2013-06-14 13:32:03.529912	3	f	1266	143	19	2013-06-14T15:32:03+02:00	t	\N
2013-06-14 13:32:03.659433	3	f	1267	144	4	ysvi003#13-06-14at15:32:03	f	\N
2013-06-14 13:32:03.659433	3	f	1268	144	5	ReqID-0000000144	t	\N
2013-06-14 13:32:03.659433	3	f	1269	144	6	1500	t	\N
2013-06-14 13:32:03.659433	3	f	1270	144	7	Command completed successfully; ending session	t	\N
2013-06-14 13:32:03.78648	3	f	1271	145	1	REG-FRED_A	f	\N
2013-06-14 13:32:03.78648	3	f	1272	145	2	EN	f	\N
2013-06-14 13:32:03.78648	3	f	1273	145	3	passwd	f	\N
2013-06-14 13:32:03.78648	3	f	1274	145	4	xerk001#13-06-14at15:32:03	f	\N
2013-06-14 13:32:03.78648	3	f	1275	145	5	ReqID-0000000145	t	\N
2013-06-14 13:32:03.78648	3	f	1276	145	6	1000	t	\N
2013-06-14 13:32:03.78648	3	f	1277	145	7	Command completed successfully	t	\N
2013-06-14 13:32:03.845724	3	f	1278	146	10	2.1.1.8.4.5.2.2.2.0.2.4.e164.arpa	f	\N
2013-06-14 13:32:03.845724	3	f	1279	146	16	TESTER	f	\N
2013-06-14 13:32:03.845724	3	f	1280	146	26	nssid01	f	\N
2013-06-14 13:32:03.845724	3	f	1281	146	27	keyid01	f	\N
2013-06-14 13:32:03.845724	3	f	1282	146	54	anna	f	\N
2013-06-14 13:32:03.845724	3	f	1283	146	54	bob	f	\N
2013-06-14 13:32:03.845724	3	f	1284	146	17	0	f	\N
2013-06-14 13:32:03.845724	3	f	1285	146	18	Month	f	\N
2013-06-14 13:32:03.845724	3	f	1286	146	4	xerk002#13-06-14at15:32:03	f	\N
2013-06-14 13:32:03.845724	3	f	1287	146	5	ReqID-0000000146	t	\N
2013-06-14 13:32:03.845724	3	f	1288	146	6	1000	t	\N
2013-06-14 13:32:03.845724	3	f	1289	146	7	Command completed successfully	t	\N
2013-06-14 13:32:03.845724	3	f	1290	146	19	2013-06-14T15:32:03+02:00	t	\N
2013-06-14 13:32:03.975974	3	f	1291	147	4	xerk003#13-06-14at15:32:03	f	\N
2013-06-14 13:32:03.975974	3	f	1292	147	5	ReqID-0000000147	t	\N
2013-06-14 13:32:03.975974	3	f	1293	147	6	1500	t	\N
2013-06-14 13:32:03.975974	3	f	1294	147	7	Command completed successfully; ending session	t	\N
2013-06-14 13:32:04.106177	3	f	1295	148	1	REG-FRED_A	f	\N
2013-06-14 13:32:04.106177	3	f	1296	148	2	EN	f	\N
2013-06-14 13:32:04.106177	3	f	1297	148	3	passwd	f	\N
2013-06-14 13:32:04.106177	3	f	1298	148	4	dxrl001#13-06-14at15:32:04	f	\N
2013-06-14 13:32:04.106177	3	f	1299	148	5	ReqID-0000000148	t	\N
2013-06-14 13:32:04.106177	3	f	1300	148	6	1000	t	\N
2013-06-14 13:32:04.106177	3	f	1301	148	7	Command completed successfully	t	\N
2013-06-14 13:32:04.16571	3	f	1302	149	10	3.1.1.8.4.5.2.2.2.0.2.4.e164.arpa	f	\N
2013-06-14 13:32:04.16571	3	f	1303	149	16	TESTER	f	\N
2013-06-14 13:32:04.16571	3	f	1304	149	26	nssid01	f	\N
2013-06-14 13:32:04.16571	3	f	1305	149	27	keyid01	f	\N
2013-06-14 13:32:04.16571	3	f	1306	149	54	anna	f	\N
2013-06-14 13:32:04.16571	3	f	1307	149	54	bob	f	\N
2013-06-14 13:32:04.16571	3	f	1308	149	17	0	f	\N
2013-06-14 13:32:04.16571	3	f	1309	149	18	Month	f	\N
2013-06-14 13:32:04.16571	3	f	1310	149	4	dxrl002#13-06-14at15:32:04	f	\N
2013-06-14 13:32:04.16571	3	f	1311	149	5	ReqID-0000000149	t	\N
2013-06-14 13:32:04.16571	3	f	1312	149	6	1000	t	\N
2013-06-14 13:32:04.16571	3	f	1313	149	7	Command completed successfully	t	\N
2013-06-14 13:32:04.16571	3	f	1314	149	19	2013-06-14T15:32:04+02:00	t	\N
2013-06-14 13:32:04.293804	3	f	1315	150	4	dxrl003#13-06-14at15:32:04	f	\N
2013-06-14 13:32:04.293804	3	f	1316	150	5	ReqID-0000000150	t	\N
2013-06-14 13:32:04.293804	3	f	1317	150	6	1500	t	\N
2013-06-14 13:32:04.293804	3	f	1318	150	7	Command completed successfully; ending session	t	\N
2013-06-14 13:32:04.424238	3	f	1319	151	1	REG-FRED_A	f	\N
2013-06-14 13:32:04.424238	3	f	1320	151	2	EN	f	\N
2013-06-14 13:32:04.424238	3	f	1321	151	3	passwd	f	\N
2013-06-14 13:32:04.424238	3	f	1322	151	4	vppb001#13-06-14at15:32:04	f	\N
2013-06-14 13:32:04.424238	3	f	1323	151	5	ReqID-0000000151	t	\N
2013-06-14 13:32:04.424238	3	f	1324	151	6	1000	t	\N
2013-06-14 13:32:04.424238	3	f	1325	151	7	Command completed successfully	t	\N
2013-06-14 13:32:04.483171	3	f	1326	152	10	4.1.1.8.4.5.2.2.2.0.2.4.e164.arpa	f	\N
2013-06-14 13:32:04.483171	3	f	1327	152	16	TESTER	f	\N
2013-06-14 13:32:04.483171	3	f	1328	152	26	nssid01	f	\N
2013-06-14 13:32:04.483171	3	f	1329	152	27	keyid01	f	\N
2013-06-14 13:32:04.483171	3	f	1330	152	54	anna	f	\N
2013-06-14 13:32:04.483171	3	f	1331	152	54	bob	f	\N
2013-06-14 13:32:04.483171	3	f	1332	152	17	0	f	\N
2013-06-14 13:32:04.483171	3	f	1333	152	18	Month	f	\N
2013-06-14 13:32:04.483171	3	f	1334	152	4	vppb002#13-06-14at15:32:04	f	\N
2013-06-14 13:32:04.483171	3	f	1335	152	5	ReqID-0000000152	t	\N
2013-06-14 13:32:04.483171	3	f	1336	152	6	1000	t	\N
2013-06-14 13:32:04.483171	3	f	1337	152	7	Command completed successfully	t	\N
2013-06-14 13:32:04.483171	3	f	1338	152	19	2013-06-14T15:32:04+02:00	t	\N
2013-06-14 13:32:04.610724	3	f	1339	153	4	vppb003#13-06-14at15:32:04	f	\N
2013-06-14 13:32:04.610724	3	f	1340	153	5	ReqID-0000000153	t	\N
2013-06-14 13:32:04.610724	3	f	1341	153	6	1500	t	\N
2013-06-14 13:32:04.610724	3	f	1342	153	7	Command completed successfully; ending session	t	\N
2013-06-14 13:32:04.740122	3	f	1343	154	1	REG-FRED_A	f	\N
2013-06-14 13:32:04.740122	3	f	1344	154	2	EN	f	\N
2013-06-14 13:32:04.740122	3	f	1345	154	3	passwd	f	\N
2013-06-14 13:32:04.740122	3	f	1346	154	4	llna001#13-06-14at15:32:04	f	\N
2013-06-14 13:32:04.740122	3	f	1347	154	5	ReqID-0000000154	t	\N
2013-06-14 13:32:04.740122	3	f	1348	154	6	1000	t	\N
2013-06-14 13:32:04.740122	3	f	1349	154	7	Command completed successfully	t	\N
2013-06-14 13:32:04.799478	3	f	1350	155	10	5.1.1.8.4.5.2.2.2.0.2.4.e164.arpa	f	\N
2013-06-14 13:32:04.799478	3	f	1351	155	16	TESTER	f	\N
2013-06-14 13:32:04.799478	3	f	1352	155	26	nssid01	f	\N
2013-06-14 13:32:04.799478	3	f	1353	155	27	keyid01	f	\N
2013-06-14 13:32:04.799478	3	f	1354	155	54	anna	f	\N
2013-06-14 13:32:04.799478	3	f	1355	155	54	bob	f	\N
2013-06-14 13:32:04.799478	3	f	1356	155	17	0	f	\N
2013-06-14 13:32:04.799478	3	f	1357	155	18	Month	f	\N
2013-06-14 13:32:04.799478	3	f	1358	155	4	llna002#13-06-14at15:32:04	f	\N
2013-06-14 13:32:04.799478	3	f	1359	155	5	ReqID-0000000155	t	\N
2013-06-14 13:32:04.799478	3	f	1360	155	6	1000	t	\N
2013-06-14 13:32:04.799478	3	f	1361	155	7	Command completed successfully	t	\N
2013-06-14 13:32:04.799478	3	f	1362	155	19	2013-06-14T15:32:04+02:00	t	\N
2013-06-14 13:32:04.928523	3	f	1363	156	4	llna003#13-06-14at15:32:04	f	\N
2013-06-14 13:32:04.928523	3	f	1364	156	5	ReqID-0000000156	t	\N
2013-06-14 13:32:04.928523	3	f	1365	156	6	1500	t	\N
2013-06-14 13:32:04.928523	3	f	1366	156	7	Command completed successfully; ending session	t	\N
2013-06-14 13:32:05.057386	3	f	1367	157	1	REG-FRED_A	f	\N
2013-06-14 13:32:05.057386	3	f	1368	157	2	EN	f	\N
2013-06-14 13:32:05.057386	3	f	1369	157	3	passwd	f	\N
2013-06-14 13:32:05.057386	3	f	1370	157	4	yovx001#13-06-14at15:32:05	f	\N
2013-06-14 13:32:05.057386	3	f	1371	157	5	ReqID-0000000157	t	\N
2013-06-14 13:32:05.057386	3	f	1372	157	6	1000	t	\N
2013-06-14 13:32:05.057386	3	f	1373	157	7	Command completed successfully	t	\N
2013-06-14 13:32:05.117046	3	f	1374	158	10	6.1.1.8.4.5.2.2.2.0.2.4.e164.arpa	f	\N
2013-06-14 13:32:05.117046	3	f	1375	158	16	TESTER	f	\N
2013-06-14 13:32:05.117046	3	f	1376	158	26	nssid01	f	\N
2013-06-14 13:32:05.117046	3	f	1377	158	27	keyid01	f	\N
2013-06-14 13:32:05.117046	3	f	1378	158	54	anna	f	\N
2013-06-14 13:32:05.117046	3	f	1379	158	54	bob	f	\N
2013-06-14 13:32:05.117046	3	f	1380	158	17	0	f	\N
2013-06-14 13:32:05.117046	3	f	1381	158	18	Month	f	\N
2013-06-14 13:32:05.117046	3	f	1382	158	4	yovx002#13-06-14at15:32:05	f	\N
2013-06-14 13:32:05.117046	3	f	1383	158	5	ReqID-0000000158	t	\N
2013-06-14 13:32:05.117046	3	f	1384	158	6	1000	t	\N
2013-06-14 13:32:05.117046	3	f	1385	158	7	Command completed successfully	t	\N
2013-06-14 13:32:05.117046	3	f	1386	158	19	2013-06-14T15:32:05+02:00	t	\N
2013-06-14 13:32:05.245854	3	f	1387	159	4	yovx003#13-06-14at15:32:05	f	\N
2013-06-14 13:32:05.245854	3	f	1388	159	5	ReqID-0000000159	t	\N
2013-06-14 13:32:05.245854	3	f	1389	159	6	1500	t	\N
2013-06-14 13:32:05.245854	3	f	1390	159	7	Command completed successfully; ending session	t	\N
2013-06-14 13:32:05.37904	3	f	1391	160	1	REG-FRED_A	f	\N
2013-06-14 13:32:05.37904	3	f	1392	160	2	EN	f	\N
2013-06-14 13:32:05.37904	3	f	1393	160	3	passwd	f	\N
2013-06-14 13:32:05.37904	3	f	1394	160	4	tzzp001#13-06-14at15:32:05	f	\N
2013-06-14 13:32:05.37904	3	f	1395	160	5	ReqID-0000000160	t	\N
2013-06-14 13:32:05.37904	3	f	1396	160	6	1000	t	\N
2013-06-14 13:32:05.37904	3	f	1397	160	7	Command completed successfully	t	\N
2013-06-14 13:32:05.438573	3	f	1398	161	10	7.1.1.8.4.5.2.2.2.0.2.4.e164.arpa	f	\N
2013-06-14 13:32:05.438573	3	f	1399	161	16	TESTER	f	\N
2013-06-14 13:32:05.438573	3	f	1400	161	26	nssid01	f	\N
2013-06-14 13:32:05.438573	3	f	1401	161	27	keyid01	f	\N
2013-06-14 13:32:05.438573	3	f	1402	161	54	anna	f	\N
2013-06-14 13:32:05.438573	3	f	1403	161	54	bob	f	\N
2013-06-14 13:32:05.438573	3	f	1404	161	17	0	f	\N
2013-06-14 13:32:05.438573	3	f	1405	161	18	Month	f	\N
2013-06-14 13:32:05.438573	3	f	1406	161	4	tzzp002#13-06-14at15:32:05	f	\N
2013-06-14 13:32:05.438573	3	f	1407	161	5	ReqID-0000000161	t	\N
2013-06-14 13:32:05.438573	3	f	1408	161	6	1000	t	\N
2013-06-14 13:32:05.438573	3	f	1409	161	7	Command completed successfully	t	\N
2013-06-14 13:32:05.438573	3	f	1410	161	19	2013-06-14T15:32:05+02:00	t	\N
2013-06-14 13:32:05.567124	3	f	1411	162	4	tzzp003#13-06-14at15:32:05	f	\N
2013-06-14 13:32:05.567124	3	f	1412	162	5	ReqID-0000000162	t	\N
2013-06-14 13:32:05.567124	3	f	1413	162	6	1500	t	\N
2013-06-14 13:32:05.567124	3	f	1414	162	7	Command completed successfully; ending session	t	\N
2013-06-14 13:32:05.69046	3	f	1415	163	1	REG-FRED_A	f	\N
2013-06-14 13:32:05.69046	3	f	1416	163	2	EN	f	\N
2013-06-14 13:32:05.69046	3	f	1417	163	3	passwd	f	\N
2013-06-14 13:32:05.69046	3	f	1418	163	4	kwfg001#13-06-14at15:32:05	f	\N
2013-06-14 13:32:05.69046	3	f	1419	163	5	ReqID-0000000163	t	\N
2013-06-14 13:32:05.69046	3	f	1420	163	6	1000	t	\N
2013-06-14 13:32:05.69046	3	f	1421	163	7	Command completed successfully	t	\N
2013-06-14 13:32:05.747844	3	f	1422	164	10	8.1.1.8.4.5.2.2.2.0.2.4.e164.arpa	f	\N
2013-06-14 13:32:05.747844	3	f	1423	164	16	TESTER	f	\N
2013-06-14 13:32:05.747844	3	f	1424	164	26	nssid01	f	\N
2013-06-14 13:32:05.747844	3	f	1425	164	27	keyid01	f	\N
2013-06-14 13:32:05.747844	3	f	1426	164	54	anna	f	\N
2013-06-14 13:32:05.747844	3	f	1427	164	54	bob	f	\N
2013-06-14 13:32:05.747844	3	f	1428	164	17	0	f	\N
2013-06-14 13:32:05.747844	3	f	1429	164	18	Month	f	\N
2013-06-14 13:32:05.747844	3	f	1430	164	4	kwfg002#13-06-14at15:32:05	f	\N
2013-06-14 13:32:05.747844	3	f	1431	164	5	ReqID-0000000164	t	\N
2013-06-14 13:32:05.747844	3	f	1432	164	6	1000	t	\N
2013-06-14 13:32:05.747844	3	f	1433	164	7	Command completed successfully	t	\N
2013-06-14 13:32:05.747844	3	f	1434	164	19	2013-06-14T15:32:05+02:00	t	\N
2013-06-14 13:32:05.875628	3	f	1435	165	4	kwfg003#13-06-14at15:32:05	f	\N
2013-06-14 13:32:05.875628	3	f	1436	165	5	ReqID-0000000165	t	\N
2013-06-14 13:32:05.875628	3	f	1437	165	6	1500	t	\N
2013-06-14 13:32:05.875628	3	f	1438	165	7	Command completed successfully; ending session	t	\N
2013-06-14 13:32:05.998781	3	f	1439	166	1	REG-FRED_A	f	\N
2013-06-14 13:32:05.998781	3	f	1440	166	2	EN	f	\N
2013-06-14 13:32:05.998781	3	f	1441	166	3	passwd	f	\N
2013-06-14 13:32:05.998781	3	f	1442	166	4	qxcq001#13-06-14at15:32:05	f	\N
2013-06-14 13:32:05.998781	3	f	1443	166	5	ReqID-0000000166	t	\N
2013-06-14 13:32:05.998781	3	f	1444	166	6	1000	t	\N
2013-06-14 13:32:05.998781	3	f	1445	166	7	Command completed successfully	t	\N
2013-06-14 13:32:06.058387	3	f	1446	167	10	9.1.1.8.4.5.2.2.2.0.2.4.e164.arpa	f	\N
2013-06-14 13:32:06.058387	3	f	1447	167	16	TESTER	f	\N
2013-06-14 13:32:06.058387	3	f	1448	167	26	nssid01	f	\N
2013-06-14 13:32:06.058387	3	f	1449	167	27	keyid01	f	\N
2013-06-14 13:32:06.058387	3	f	1450	167	54	anna	f	\N
2013-06-14 13:32:06.058387	3	f	1451	167	54	bob	f	\N
2013-06-14 13:32:06.058387	3	f	1452	167	17	0	f	\N
2013-06-14 13:32:06.058387	3	f	1453	167	18	Month	f	\N
2013-06-14 13:32:06.058387	3	f	1454	167	4	qxcq002#13-06-14at15:32:06	f	\N
2013-06-14 13:32:06.058387	3	f	1455	167	5	ReqID-0000000167	t	\N
2013-06-14 13:32:06.058387	3	f	1456	167	6	1000	t	\N
2013-06-14 13:32:06.058387	3	f	1457	167	7	Command completed successfully	t	\N
2013-06-14 13:32:06.058387	3	f	1458	167	19	2013-06-14T15:32:06+02:00	t	\N
2013-06-14 13:32:06.186072	3	f	1459	168	4	qxcq003#13-06-14at15:32:06	f	\N
2013-06-14 13:32:06.186072	3	f	1460	168	5	ReqID-0000000168	t	\N
2013-06-14 13:32:06.186072	3	f	1461	168	6	1500	t	\N
2013-06-14 13:32:06.186072	3	f	1462	168	7	Command completed successfully; ending session	t	\N
2013-06-14 13:32:06.308321	3	f	1463	169	1	REG-FRED_A	f	\N
2013-06-14 13:32:06.308321	3	f	1464	169	2	EN	f	\N
2013-06-14 13:32:06.308321	3	f	1465	169	3	passwd	f	\N
2013-06-14 13:32:06.308321	3	f	1466	169	4	qwua001#13-06-14at15:32:06	f	\N
2013-06-14 13:32:06.308321	3	f	1467	169	5	ReqID-0000000169	t	\N
2013-06-14 13:32:06.308321	3	f	1468	169	6	1000	t	\N
2013-06-14 13:32:06.308321	3	f	1469	169	7	Command completed successfully	t	\N
2013-06-14 13:32:06.36519	3	f	1470	170	10	0.2.1.8.4.5.2.2.2.0.2.4.e164.arpa	f	\N
2013-06-14 13:32:06.36519	3	f	1471	170	16	TESTER	f	\N
2013-06-14 13:32:06.36519	3	f	1472	170	26	nssid01	f	\N
2013-06-14 13:32:06.36519	3	f	1473	170	27	keyid01	f	\N
2013-06-14 13:32:06.36519	3	f	1474	170	54	anna	f	\N
2013-06-14 13:32:06.36519	3	f	1475	170	54	bob	f	\N
2013-06-14 13:32:06.36519	3	f	1476	170	17	0	f	\N
2013-06-14 13:32:06.36519	3	f	1477	170	18	Month	f	\N
2013-06-14 13:32:06.36519	3	f	1478	170	4	qwua002#13-06-14at15:32:06	f	\N
2013-06-14 13:32:06.36519	3	f	1479	170	5	ReqID-0000000170	t	\N
2013-06-14 13:32:06.36519	3	f	1480	170	6	1000	t	\N
2013-06-14 13:32:06.36519	3	f	1481	170	7	Command completed successfully	t	\N
2013-06-14 13:32:06.36519	3	f	1482	170	19	2013-06-14T15:32:06+02:00	t	\N
2013-06-14 13:32:06.493315	3	f	1483	171	4	qwua003#13-06-14at15:32:06	f	\N
2013-06-14 13:32:06.493315	3	f	1484	171	5	ReqID-0000000171	t	\N
2013-06-14 13:32:06.493315	3	f	1485	171	6	1500	t	\N
2013-06-14 13:32:06.493315	3	f	1486	171	7	Command completed successfully; ending session	t	\N
2013-06-14 13:32:06.617628	3	f	1487	172	1	REG-FRED_A	f	\N
2013-06-14 13:32:06.617628	3	f	1488	172	2	EN	f	\N
2013-06-14 13:32:06.617628	3	f	1489	172	3	passwd	f	\N
2013-06-14 13:32:06.617628	3	f	1490	172	4	klhr001#13-06-14at15:32:06	f	\N
2013-06-14 13:32:06.617628	3	f	1491	172	5	ReqID-0000000172	t	\N
2013-06-14 13:32:06.617628	3	f	1492	172	6	1000	t	\N
2013-06-14 13:32:06.617628	3	f	1493	172	7	Command completed successfully	t	\N
2013-06-14 13:32:06.676859	3	f	1494	173	10	1.2.1.8.4.5.2.2.2.0.2.4.e164.arpa	f	\N
2013-06-14 13:32:06.676859	3	f	1495	173	16	TESTER	f	\N
2013-06-14 13:32:06.676859	3	f	1496	173	26	nssid01	f	\N
2013-06-14 13:32:06.676859	3	f	1497	173	27	keyid01	f	\N
2013-06-14 13:32:06.676859	3	f	1498	173	54	anna	f	\N
2013-06-14 13:32:06.676859	3	f	1499	173	54	bob	f	\N
2013-06-14 13:32:06.676859	3	f	1500	173	17	0	f	\N
2013-06-14 13:32:06.676859	3	f	1501	173	18	Month	f	\N
2013-06-14 13:32:06.676859	3	f	1502	173	4	klhr002#13-06-14at15:32:06	f	\N
2013-06-14 13:32:06.676859	3	f	1503	173	5	ReqID-0000000173	t	\N
2013-06-14 13:32:06.676859	3	f	1504	173	6	1000	t	\N
2013-06-14 13:32:06.676859	3	f	1505	173	7	Command completed successfully	t	\N
2013-06-14 13:32:06.676859	3	f	1506	173	19	2013-06-14T15:32:06+02:00	t	\N
2013-06-14 13:32:06.805535	3	f	1507	174	4	klhr003#13-06-14at15:32:06	f	\N
2013-06-14 13:32:06.805535	3	f	1508	174	5	ReqID-0000000174	t	\N
2013-06-14 13:32:06.805535	3	f	1509	174	6	1500	t	\N
2013-06-14 13:32:06.805535	3	f	1510	174	7	Command completed successfully; ending session	t	\N
\.


--
-- Data for Name: request_type; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY request_type (id, name, service_id) FROM stdin;
1105	Info	0
1104	Info	1
1600	AuthInfo	2
1601	BlockTransfer	2
1602	BlockChanges	2
1603	UnblockTransfer	2
1604	UnblockChanges	2
1605	Verification	2
1606	ConditionalIdentification	2
1607	Identification	2
100	ClientLogin	3
101	ClientLogout	3
105	ClientGreeting	3
120	PollAcknowledgement	3
121	PollResponse	3
200	ContactCheck	3
201	ContactInfo	3
202	ContactDelete	3
203	ContactUpdate	3
204	ContactCreate	3
205	ContactTransfer	3
400	NSsetCheck	3
401	NSsetInfo	3
402	NSsetDelete	3
403	NSsetUpdate	3
404	NSsetCreate	3
405	NSsetTransfer	3
500	DomainCheck	3
501	DomainInfo	3
502	DomainDelete	3
503	DomainUpdate	3
504	DomainCreate	3
505	DomainTransfer	3
506	DomainRenew	3
507	DomainTrade	3
1000	UnknownAction	3
1002	ListContact	3
1004	ListNSset	3
1005	ListDomain	3
1010	ClientCredit	3
1012	nssetTest	3
1101	ContactSendAuthInfo	3
1102	NSSetSendAuthInfo	3
1103	DomainSendAuthInfo	3
1106	KeySetSendAuthInfo	3
600	KeysetCheck	3
601	KeysetInfo	3
602	KeysetDelete	3
603	KeysetUpdate	3
604	KeysetCreate	3
605	KeysetTransfer	3
1006	ListKeySet	3
1200	InfoListContacts	3
1201	InfoListDomains	3
1202	InfoListNssets	3
1203	InfoListKeysets	3
1204	InfoDomainsByNsset	3
1205	InfoDomainsByKeyset	3
1206	InfoDomainsByContact	3
1207	InfoNssetsByContact	3
1208	InfoNssetsByNs	3
1209	InfoKeysetsByContact	3
1210	InfoGetResults	3
1300	Login	4
1301	Logout	4
1302	DomainFilter	4
1303	ContactFilter	4
1304	NSSetFilter	4
1305	KeySetFilter	4
1306	RegistrarFilter	4
1307	InvoiceFilter	4
1308	EmailsFilter	4
1309	FileFilter	4
1310	ActionsFilter	4
1311	PublicRequestFilter	4
1312	DomainDetail	4
1313	ContactDetail	4
1314	NSSetDetail	4
1315	KeySetDetail	4
1316	RegistrarDetail	4
1317	InvoiceDetail	4
1318	EmailsDetail	4
1319	FileDetail	4
1320	ActionsDetail	4
1321	PublicRequestDetail	4
1322	RegistrarCreate	4
1323	RegistrarUpdate	4
1324	PublicRequestAccept	4
1325	PublicRequestInvalidate	4
1326	DomainDig	4
1327	FilterCreate	4
1328	RequestDetail	4
1329	RequestFilter	4
1330	BankStatementDetail	4
1331	BankStatementFilter	4
1332	PaymentPair	4
1333	SetInZoneStatus	4
1334	SaveFilter	4
1335	LoadFilter	4
1336	CreateRegistrarGroup	4
1337	DeleteRegistrarGroup	4
1338	UpdateRegistrarGroup	4
1339	MessageDetail	4
1340	MessageFilter	4
1341	ContactNotifyPdf	4
1400	Login	5
1401	Logout	5
1402	DisplaySummary	5
1403	InvoiceList	5
1404	DomainList	5
1405	FileDetail	5
1500	OpenIDRequest	6
1501	Login	6
1502	Logout	6
1504	UserChange	6
1507	PasswordResetRequest	6
1509	TrustChange	6
1511	AccountStateChange	6
1512	AuthChange	6
1700	Login	7
1701	Logout	7
1702	BlockingChange	7
1703	DiscloseChange	7
1704	Browse	7
1705	Detail	7
1706	AuthInfoChange	7
\.


--
-- Data for Name: result_code; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY result_code (id, service_id, result_code, name) FROM stdin;
1	0	101	NoEntriesFound
2	0	107	UsageError
3	0	108	InvalidRequest
4	0	501	InternalServerError
5	0	0	Ok
6	1	0	Ok
7	1	1	NotFound
8	1	2	Error
9	3	1000	CommandCompletedSuccessfully
10	3	1001	CommandCompletedSuccessfullyActionPending
11	3	1300	CommandCompletedSuccessfullyNoMessages
12	3	1301	CommandCompletedSuccessfullyAckToDequeue
13	3	1500	CommandCompletedSuccessfullyEndingSession
14	3	2000	UnknownCommand
15	3	2001	CommandSyntaxError
16	3	2002	CommandUseError
17	3	2003	RequiredParameterMissing
18	3	2004	ParameterValueRangeError
19	3	2005	ParameterValueSyntaxError
20	3	2100	UnimplementedProtocolVersion
21	3	2101	UnimplementedCommand
22	3	2102	UnimplementedOption
23	3	2103	UnimplementedExtension
24	3	2104	BillingFailure
25	3	2105	ObjectIsNotEligibleForRenewal
26	3	2106	ObjectIsNotEligibleForTransfer
27	3	2200	AuthenticationError
28	3	2201	AuthorizationError
29	3	2202	InvalidAuthorizationInformation
30	3	2300	ObjectPendingTransfer
31	3	2301	ObjectNotPendingTransfer
32	3	2302	ObjectExists
33	3	2303	ObjectDoesNotExist
34	3	2304	ObjectStatusProhibitsOperation
35	3	2305	ObjectAssociationProhibitsOperation
36	3	2306	ParameterValuePolicyError
37	3	2307	UnimplementedObjectService
38	3	2308	DataManagementPolicyViolation
39	3	2400	CommandFailed
40	3	2500	CommandFailedServerClosingConnection
41	3	2501	AuthenticationErrorServerClosingConnection
42	3	2502	SessionLimitExceededServerClosingConnection
43	4	1	Success
44	4	2	Fail
45	4	3	Error
46	6	1	Success
47	6	2	Fail
48	6	3	Error
49	7	1	Success
50	7	2	Fail
51	7	3	Error
52	7	4	NotValidated
53	7	5	Warning
54	2	0	Ok
55	2	1	Error
56	2	2	Fail
\.


--
-- Data for Name: service; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY service (id, partition_postfix, name) FROM stdin;
0	whois_	Unix whois
1	webwhois_	Web whois
2	pubreq_	Public Request
3	epp_	EPP
4	webadmin_	WebAdmin
5	intranet_	Intranet
6	mojeid_	MojeID
7	d_browser_	Domainbrowser
\.


--
-- Data for Name: session; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY session (id, user_name, login_date, logout_date, user_id) FROM stdin;
\.


--
-- Data for Name: session_13_06; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY session_13_06 (id, user_name, login_date, logout_date, user_id) FROM stdin;
1	REG-FRED_A	2013-06-14 13:31:49.41807	2013-06-14 13:31:49.597256	\N
2	REG-FRED_A	2013-06-14 13:31:49.721411	2013-06-14 13:31:49.886366	\N
3	REG-FRED_A	2013-06-14 13:31:50.015906	2013-06-14 13:31:50.182503	\N
4	REG-FRED_A	2013-06-14 13:31:50.314712	2013-06-14 13:31:50.478727	\N
5	REG-FRED_A	2013-06-14 13:31:50.615255	2013-06-14 13:31:50.780554	\N
6	REG-FRED_A	2013-06-14 13:31:50.909718	2013-06-14 13:31:51.078562	\N
7	REG-FRED_A	2013-06-14 13:31:51.21497	2013-06-14 13:31:51.380065	\N
8	REG-FRED_A	2013-06-14 13:31:51.639187	2013-06-14 13:31:51.804427	\N
9	REG-FRED_A	2013-06-14 13:31:51.92769	2013-06-14 13:31:52.088549	\N
10	REG-FRED_A	2013-06-14 13:31:52.222395	2013-06-14 13:31:52.384313	\N
11	REG-FRED_A	2013-06-14 13:31:52.513711	2013-06-14 13:31:52.656859	\N
12	REG-FRED_A	2013-06-14 13:31:52.794346	2013-06-14 13:31:52.958594	\N
13	REG-FRED_A	2013-06-14 13:31:53.085539	2013-06-14 13:31:53.247531	\N
14	REG-FRED_A	2013-06-14 13:31:53.381973	2013-06-14 13:31:53.543701	\N
15	REG-FRED_A	2013-06-14 13:31:53.675789	2013-06-14 13:31:53.837667	\N
16	REG-FRED_A	2013-06-14 13:31:53.973403	2013-06-14 13:31:54.134962	\N
17	REG-FRED_A	2013-06-14 13:31:54.261229	2013-06-14 13:31:54.423683	\N
18	REG-FRED_A	2013-06-14 13:31:54.558362	2013-06-14 13:31:54.707217	\N
19	REG-FRED_A	2013-06-14 13:31:54.843248	2013-06-14 13:31:54.970112	\N
20	REG-FRED_A	2013-06-14 13:31:55.101831	2013-06-14 13:31:55.250009	\N
21	REG-FRED_A	2013-06-14 13:31:55.37855	2013-06-14 13:31:55.527461	\N
22	REG-FRED_A	2013-06-14 13:31:55.663143	2013-06-14 13:31:55.810462	\N
23	REG-FRED_A	2013-06-14 13:31:55.943145	2013-06-14 13:31:56.091844	\N
24	REG-FRED_A	2013-06-14 13:31:56.218587	2013-06-14 13:31:56.366767	\N
25	REG-FRED_A	2013-06-14 13:31:56.499958	2013-06-14 13:31:56.649402	\N
26	REG-FRED_A	2013-06-14 13:31:56.782245	2013-06-14 13:31:56.932749	\N
27	REG-FRED_A	2013-06-14 13:31:57.062765	2013-06-14 13:31:57.21403	\N
28	REG-FRED_A	2013-06-14 13:31:57.333775	2013-06-14 13:31:57.516461	\N
29	REG-FRED_A	2013-06-14 13:31:57.640699	2013-06-14 13:31:57.818288	\N
30	REG-FRED_A	2013-06-14 13:31:57.955781	2013-06-14 13:31:58.135225	\N
31	REG-FRED_A	2013-06-14 13:31:58.274613	2013-06-14 13:31:58.453642	\N
32	REG-FRED_A	2013-06-14 13:31:58.583322	2013-06-14 13:31:58.7655	\N
33	REG-FRED_A	2013-06-14 13:31:58.893809	2013-06-14 13:31:59.074786	\N
34	REG-FRED_A	2013-06-14 13:31:59.203883	2013-06-14 13:31:59.383045	\N
35	REG-FRED_A	2013-06-14 13:31:59.513836	2013-06-14 13:31:59.696841	\N
36	REG-FRED_A	2013-06-14 13:31:59.824787	2013-06-14 13:32:00.003692	\N
37	REG-FRED_A	2013-06-14 13:32:00.129189	2013-06-14 13:32:00.309942	\N
38	REG-FRED_A	2013-06-14 13:32:00.436565	2013-06-14 13:32:00.609374	\N
39	REG-FRED_A	2013-06-14 13:32:00.73578	2013-06-14 13:32:00.910367	\N
40	REG-FRED_A	2013-06-14 13:32:01.040836	2013-06-14 13:32:01.214914	\N
41	REG-FRED_A	2013-06-14 13:32:01.353352	2013-06-14 13:32:01.527953	\N
42	REG-FRED_A	2013-06-14 13:32:01.663972	2013-06-14 13:32:01.837862	\N
43	REG-FRED_A	2013-06-14 13:32:01.983555	2013-06-14 13:32:02.159591	\N
44	REG-FRED_A	2013-06-14 13:32:02.287267	2013-06-14 13:32:02.46138	\N
45	REG-FRED_A	2013-06-14 13:32:02.592513	2013-06-14 13:32:02.766218	\N
46	REG-FRED_A	2013-06-14 13:32:02.893892	2013-06-14 13:32:03.068939	\N
47	REG-FRED_A	2013-06-14 13:32:03.190122	2013-06-14 13:32:03.363231	\N
48	REG-FRED_A	2013-06-14 13:32:03.495861	2013-06-14 13:32:03.678068	\N
49	REG-FRED_A	2013-06-14 13:32:03.811755	2013-06-14 13:32:03.994606	\N
50	REG-FRED_A	2013-06-14 13:32:04.131579	2013-06-14 13:32:04.312734	\N
51	REG-FRED_A	2013-06-14 13:32:04.449465	2013-06-14 13:32:04.629117	\N
52	REG-FRED_A	2013-06-14 13:32:04.765692	2013-06-14 13:32:04.947111	\N
53	REG-FRED_A	2013-06-14 13:32:05.083181	2013-06-14 13:32:05.264704	\N
54	REG-FRED_A	2013-06-14 13:32:05.404674	2013-06-14 13:32:05.585856	\N
55	REG-FRED_A	2013-06-14 13:32:05.713798	2013-06-14 13:32:05.894078	\N
56	REG-FRED_A	2013-06-14 13:32:06.024382	2013-06-14 13:32:06.204746	\N
57	REG-FRED_A	2013-06-14 13:32:06.33148	2013-06-14 13:32:06.511804	\N
58	REG-FRED_A	2013-06-14 13:32:06.642997	2013-06-14 13:32:06.824365	\N
\.


--
-- Data for Name: sms_archive; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY sms_archive (id, phone_number, phone_number_id, content) FROM stdin;
\.


--
-- Data for Name: user; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY "user" (id, firstname, surname) FROM stdin;
\.


--
-- Data for Name: zone; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY zone (id, fqdn, ex_period_min, ex_period_max, val_period, dots_max, enum_zone, warning_letter) FROM stdin;
1	0.2.4.e164.arpa	12	120	6	9	t	t
2	cz	12	120	0	1	f	t
\.


--
-- Data for Name: zone_ns; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY zone_ns (id, zone, fqdn, addrs) FROM stdin;
1	2	a.ns.nic.cz	{}
2	2	b.ns.nic.cz	{}
3	2	c.ns.nic.cz	{}
4	2	d.ns.nic.cz	{}
5	2	f.ns.nic.cz	{}
6	1	a.ns.nic.cz	{}
7	1	b.ns.nic.cz	{}
8	1	c.ns.nic.cz	{}
9	1	d.ns.nic.cz	{}
10	1	f.ns.nic.cz	{}
\.


--
-- Data for Name: zone_soa; Type: TABLE DATA; Schema: public; Owner: fred
--

COPY zone_soa (zone, ttl, hostmaster, serial, refresh, update_retr, expiry, minimum, ns_fqdn) FROM stdin;
1	18000	hostmaster@nic.cz	\N	900	300	604800	900	a.ns.nic.cz
2	18000	hostmaster@nic.cz	\N	900	300	604800	900	a.ns.nic.cz
\.


--
-- Name: bank_account_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY bank_account
    ADD CONSTRAINT bank_account_pkey PRIMARY KEY (id);


--
-- Name: bank_payment_account_id_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY bank_payment
    ADD CONSTRAINT bank_payment_account_id_key UNIQUE (account_id, account_evid);


--
-- Name: bank_payment_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY bank_payment
    ADD CONSTRAINT bank_payment_pkey PRIMARY KEY (id);


--
-- Name: bank_payment_registrar_credit_registrar_credit_transaction__key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY bank_payment_registrar_credit_transaction_map
    ADD CONSTRAINT bank_payment_registrar_credit_registrar_credit_transaction__key UNIQUE (registrar_credit_transaction_id);


--
-- Name: bank_payment_registrar_credit_transaction_map_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY bank_payment_registrar_credit_transaction_map
    ADD CONSTRAINT bank_payment_registrar_credit_transaction_map_pkey PRIMARY KEY (id);


--
-- Name: bank_statement_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY bank_statement
    ADD CONSTRAINT bank_statement_pkey PRIMARY KEY (id);


--
-- Name: check_dependance_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY check_dependance
    ADD CONSTRAINT check_dependance_pkey PRIMARY KEY (id);


--
-- Name: check_nsset_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY check_nsset
    ADD CONSTRAINT check_nsset_pkey PRIMARY KEY (id);


--
-- Name: check_result_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY check_result
    ADD CONSTRAINT check_result_pkey PRIMARY KEY (id);


--
-- Name: check_test_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY check_test
    ADD CONSTRAINT check_test_pkey PRIMARY KEY (id);


--
-- Name: comm_type_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY comm_type
    ADD CONSTRAINT comm_type_pkey PRIMARY KEY (id);


--
-- Name: contact_history_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY contact_history
    ADD CONSTRAINT contact_history_pkey PRIMARY KEY (historyid);


--
-- Name: contact_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY contact
    ADD CONSTRAINT contact_pkey PRIMARY KEY (id);


--
-- Name: dnskey_history_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY dnskey_history
    ADD CONSTRAINT dnskey_history_pkey PRIMARY KEY (historyid, id);


--
-- Name: dnskey_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY dnskey
    ADD CONSTRAINT dnskey_pkey PRIMARY KEY (id);


--
-- Name: dnssec_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY dnssec
    ADD CONSTRAINT dnssec_pkey PRIMARY KEY (domainid);


--
-- Name: domain_blacklist_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY domain_blacklist
    ADD CONSTRAINT domain_blacklist_pkey PRIMARY KEY (id);


--
-- Name: domain_contact_map_history_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY domain_contact_map_history
    ADD CONSTRAINT domain_contact_map_history_pkey PRIMARY KEY (historyid, domainid, contactid);


--
-- Name: domain_contact_map_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY domain_contact_map
    ADD CONSTRAINT domain_contact_map_pkey PRIMARY KEY (domainid, contactid);


--
-- Name: domain_history_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY domain_history
    ADD CONSTRAINT domain_history_pkey PRIMARY KEY (historyid);


--
-- Name: domain_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY domain
    ADD CONSTRAINT domain_pkey PRIMARY KEY (id);


--
-- Name: dsrecord_history_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY dsrecord_history
    ADD CONSTRAINT dsrecord_history_pkey PRIMARY KEY (historyid, id);


--
-- Name: dsrecord_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY dsrecord
    ADD CONSTRAINT dsrecord_pkey PRIMARY KEY (id);


--
-- Name: enum_bank_code_name_full_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enum_bank_code
    ADD CONSTRAINT enum_bank_code_name_full_key UNIQUE (name_full);


--
-- Name: enum_bank_code_name_short_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enum_bank_code
    ADD CONSTRAINT enum_bank_code_name_short_key UNIQUE (name_short);


--
-- Name: enum_bank_code_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enum_bank_code
    ADD CONSTRAINT enum_bank_code_pkey PRIMARY KEY (code);


--
-- Name: enum_country_country_cs_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enum_country
    ADD CONSTRAINT enum_country_country_cs_key UNIQUE (country_cs);


--
-- Name: enum_country_country_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enum_country
    ADD CONSTRAINT enum_country_country_key UNIQUE (country);


--
-- Name: enum_country_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enum_country
    ADD CONSTRAINT enum_country_pkey PRIMARY KEY (id);


--
-- Name: enum_error_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enum_error
    ADD CONSTRAINT enum_error_pkey PRIMARY KEY (id);


--
-- Name: enum_error_status_cs_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enum_error
    ADD CONSTRAINT enum_error_status_cs_key UNIQUE (status_cs);


--
-- Name: enum_error_status_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enum_error
    ADD CONSTRAINT enum_error_status_key UNIQUE (status);


--
-- Name: enum_filetype_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enum_filetype
    ADD CONSTRAINT enum_filetype_pkey PRIMARY KEY (id);


--
-- Name: enum_object_states_desc_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enum_object_states_desc
    ADD CONSTRAINT enum_object_states_desc_pkey PRIMARY KEY (state_id, lang);


--
-- Name: enum_object_states_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enum_object_states
    ADD CONSTRAINT enum_object_states_pkey PRIMARY KEY (id);


--
-- Name: enum_operation_operation_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enum_operation
    ADD CONSTRAINT enum_operation_operation_key UNIQUE (operation);


--
-- Name: enum_operation_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enum_operation
    ADD CONSTRAINT enum_operation_pkey PRIMARY KEY (id);


--
-- Name: enum_parameters_name_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enum_parameters
    ADD CONSTRAINT enum_parameters_name_key UNIQUE (name);


--
-- Name: enum_parameters_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enum_parameters
    ADD CONSTRAINT enum_parameters_pkey PRIMARY KEY (id);


--
-- Name: enum_public_request_status_name_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enum_public_request_status
    ADD CONSTRAINT enum_public_request_status_name_key UNIQUE (name);


--
-- Name: enum_public_request_status_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enum_public_request_status
    ADD CONSTRAINT enum_public_request_status_pkey PRIMARY KEY (id);


--
-- Name: enum_public_request_type_name_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enum_public_request_type
    ADD CONSTRAINT enum_public_request_type_name_key UNIQUE (name);


--
-- Name: enum_public_request_type_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enum_public_request_type
    ADD CONSTRAINT enum_public_request_type_pkey PRIMARY KEY (id);


--
-- Name: enum_reason_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enum_reason
    ADD CONSTRAINT enum_reason_pkey PRIMARY KEY (id);


--
-- Name: enum_reason_reason_cs_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enum_reason
    ADD CONSTRAINT enum_reason_reason_cs_key UNIQUE (reason_cs);


--
-- Name: enum_reason_reason_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enum_reason
    ADD CONSTRAINT enum_reason_reason_key UNIQUE (reason);


--
-- Name: enum_send_status_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enum_send_status
    ADD CONSTRAINT enum_send_status_pkey PRIMARY KEY (id);


--
-- Name: enum_send_status_status_name_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enum_send_status
    ADD CONSTRAINT enum_send_status_status_name_key UNIQUE (status_name);


--
-- Name: enum_ssntype_description_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enum_ssntype
    ADD CONSTRAINT enum_ssntype_description_key UNIQUE (description);


--
-- Name: enum_ssntype_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enum_ssntype
    ADD CONSTRAINT enum_ssntype_pkey PRIMARY KEY (id);


--
-- Name: enum_ssntype_type_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enum_ssntype
    ADD CONSTRAINT enum_ssntype_type_key UNIQUE (type);


--
-- Name: enum_tlds_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enum_tlds
    ADD CONSTRAINT enum_tlds_pkey PRIMARY KEY (tld);


--
-- Name: enumval_history_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enumval_history
    ADD CONSTRAINT enumval_history_pkey PRIMARY KEY (historyid);


--
-- Name: enumval_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY enumval
    ADD CONSTRAINT enumval_pkey PRIMARY KEY (domainid);


--
-- Name: epp_info_buffer_content_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY epp_info_buffer_content
    ADD CONSTRAINT epp_info_buffer_content_pkey PRIMARY KEY (id, registrar_id);


--
-- Name: epp_info_buffer_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY epp_info_buffer
    ADD CONSTRAINT epp_info_buffer_pkey PRIMARY KEY (registrar_id);


--
-- Name: files_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY files
    ADD CONSTRAINT files_pkey PRIMARY KEY (id);


--
-- Name: filters_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY filters
    ADD CONSTRAINT filters_pkey PRIMARY KEY (id);


--
-- Name: genzone_domain_history_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY genzone_domain_history
    ADD CONSTRAINT genzone_domain_history_pkey PRIMARY KEY (id);


--
-- Name: genzone_domain_status_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY genzone_domain_status
    ADD CONSTRAINT genzone_domain_status_pkey PRIMARY KEY (id);


--
-- Name: history_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY history
    ADD CONSTRAINT history_pkey PRIMARY KEY (id);


--
-- Name: host_history_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY host_history
    ADD CONSTRAINT host_history_pkey PRIMARY KEY (historyid, id);


--
-- Name: host_ipaddr_map_history_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY host_ipaddr_map_history
    ADD CONSTRAINT host_ipaddr_map_history_pkey PRIMARY KEY (historyid, id);


--
-- Name: host_ipaddr_map_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY host_ipaddr_map
    ADD CONSTRAINT host_ipaddr_map_pkey PRIMARY KEY (id);


--
-- Name: host_nssetid_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY host
    ADD CONSTRAINT host_nssetid_key UNIQUE (nssetid, fqdn);


--
-- Name: host_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY host
    ADD CONSTRAINT host_pkey PRIMARY KEY (id);


--
-- Name: invoice_credit_payment_map_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY invoice_credit_payment_map
    ADD CONSTRAINT invoice_credit_payment_map_pkey PRIMARY KEY (ac_invoice_id, ad_invoice_id);


--
-- Name: invoice_generation_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY invoice_generation
    ADD CONSTRAINT invoice_generation_pkey PRIMARY KEY (id);


--
-- Name: invoice_mails_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY invoice_mails
    ADD CONSTRAINT invoice_mails_pkey PRIMARY KEY (id);


--
-- Name: invoice_number_prefix_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY invoice_number_prefix
    ADD CONSTRAINT invoice_number_prefix_pkey PRIMARY KEY (id);


--
-- Name: invoice_number_prefix_unique_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY invoice_number_prefix
    ADD CONSTRAINT invoice_number_prefix_unique_key UNIQUE (zone_id, invoice_type_id);


--
-- Name: invoice_operation_charge_map_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY invoice_operation_charge_map
    ADD CONSTRAINT invoice_operation_charge_map_pkey PRIMARY KEY (invoice_operation_id, invoice_id);


--
-- Name: invoice_operation_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY invoice_operation
    ADD CONSTRAINT invoice_operation_pkey PRIMARY KEY (id);


--
-- Name: invoice_operation_registrar_credit_transaction_id_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY invoice_operation
    ADD CONSTRAINT invoice_operation_registrar_credit_transaction_id_key UNIQUE (registrar_credit_transaction_id);


--
-- Name: invoice_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY invoice
    ADD CONSTRAINT invoice_pkey PRIMARY KEY (id);


--
-- Name: invoice_prefix_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY invoice
    ADD CONSTRAINT invoice_prefix_key UNIQUE (prefix);


--
-- Name: invoice_prefix_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY invoice_prefix
    ADD CONSTRAINT invoice_prefix_pkey PRIMARY KEY (id);


--
-- Name: invoice_prefix_zone_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY invoice_prefix
    ADD CONSTRAINT invoice_prefix_zone_key UNIQUE (zone_id, typ, year);


--
-- Name: invoice_registrar_credit_tran_registrar_credit_transaction__key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY invoice_registrar_credit_transaction_map
    ADD CONSTRAINT invoice_registrar_credit_tran_registrar_credit_transaction__key UNIQUE (registrar_credit_transaction_id);


--
-- Name: invoice_registrar_credit_transaction_map_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY invoice_registrar_credit_transaction_map
    ADD CONSTRAINT invoice_registrar_credit_transaction_map_pkey PRIMARY KEY (id);


--
-- Name: invoice_type_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY invoice_type
    ADD CONSTRAINT invoice_type_pkey PRIMARY KEY (id);


--
-- Name: keyset_contact_map_history_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY keyset_contact_map_history
    ADD CONSTRAINT keyset_contact_map_history_pkey PRIMARY KEY (historyid, contactid, keysetid);


--
-- Name: keyset_contact_map_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY keyset_contact_map
    ADD CONSTRAINT keyset_contact_map_pkey PRIMARY KEY (contactid, keysetid);


--
-- Name: keyset_history_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY keyset_history
    ADD CONSTRAINT keyset_history_pkey PRIMARY KEY (historyid);


--
-- Name: keyset_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY keyset
    ADD CONSTRAINT keyset_pkey PRIMARY KEY (id);


--
-- Name: letter_archive_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY letter_archive
    ADD CONSTRAINT letter_archive_pkey PRIMARY KEY (id);


--
-- Name: mail_archive_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY mail_archive
    ADD CONSTRAINT mail_archive_pkey PRIMARY KEY (id);


--
-- Name: mail_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY mail_attachments
    ADD CONSTRAINT mail_attachments_pkey PRIMARY KEY (id);


--
-- Name: mail_defaults_name_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY mail_defaults
    ADD CONSTRAINT mail_defaults_name_key UNIQUE (name);


--
-- Name: mail_defaults_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY mail_defaults
    ADD CONSTRAINT mail_defaults_pkey PRIMARY KEY (id);


--
-- Name: mail_footer_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY mail_footer
    ADD CONSTRAINT mail_footer_pkey PRIMARY KEY (id);


--
-- Name: mail_handles_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY mail_handles
    ADD CONSTRAINT mail_handles_pkey PRIMARY KEY (id);


--
-- Name: mail_header_defaults_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY mail_header_defaults
    ADD CONSTRAINT mail_header_defaults_pkey PRIMARY KEY (id);


--
-- Name: mail_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY mail_templates
    ADD CONSTRAINT mail_templates_pkey PRIMARY KEY (id);


--
-- Name: mail_type_name_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY mail_type
    ADD CONSTRAINT mail_type_name_key UNIQUE (name);


--
-- Name: mail_type_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY mail_type
    ADD CONSTRAINT mail_type_pkey PRIMARY KEY (id);


--
-- Name: mail_type_template_map_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY mail_type_template_map
    ADD CONSTRAINT mail_type_template_map_pkey PRIMARY KEY (typeid, templateid);


--
-- Name: mail_vcard_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY mail_vcard
    ADD CONSTRAINT mail_vcard_pkey PRIMARY KEY (id);


--
-- Name: message_archive_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY message_archive
    ADD CONSTRAINT message_archive_pkey PRIMARY KEY (id);


--
-- Name: message_contact_history_map_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY message_contact_history_map
    ADD CONSTRAINT message_contact_history_map_pkey PRIMARY KEY (id);


--
-- Name: message_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY message
    ADD CONSTRAINT message_pkey PRIMARY KEY (id);


--
-- Name: message_type_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY message_type
    ADD CONSTRAINT message_type_pkey PRIMARY KEY (id);


--
-- Name: messagetype_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY messagetype
    ADD CONSTRAINT messagetype_pkey PRIMARY KEY (id);


--
-- Name: notify_letters_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY notify_letters
    ADD CONSTRAINT notify_letters_pkey PRIMARY KEY (state_id);


--
-- Name: notify_request_message_id_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY notify_request
    ADD CONSTRAINT notify_request_message_id_key UNIQUE (message_id);


--
-- Name: notify_request_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY notify_request
    ADD CONSTRAINT notify_request_pkey PRIMARY KEY (request_id, message_id);


--
-- Name: notify_statechange_map_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY notify_statechange_map
    ADD CONSTRAINT notify_statechange_map_pkey PRIMARY KEY (id);


--
-- Name: notify_statechange_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY notify_statechange
    ADD CONSTRAINT notify_statechange_pkey PRIMARY KEY (state_id, type);


--
-- Name: nsset_contact_map_history_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY nsset_contact_map_history
    ADD CONSTRAINT nsset_contact_map_history_pkey PRIMARY KEY (historyid, nssetid, contactid);


--
-- Name: nsset_contact_map_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY nsset_contact_map
    ADD CONSTRAINT nsset_contact_map_pkey PRIMARY KEY (nssetid, contactid);


--
-- Name: nsset_history_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY nsset_history
    ADD CONSTRAINT nsset_history_pkey PRIMARY KEY (historyid);


--
-- Name: nsset_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY nsset
    ADD CONSTRAINT nsset_pkey PRIMARY KEY (id);


--
-- Name: object_history_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY object_history
    ADD CONSTRAINT object_history_pkey PRIMARY KEY (historyid);


--
-- Name: object_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY object
    ADD CONSTRAINT object_pkey PRIMARY KEY (id);


--
-- Name: object_registry_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY object_registry
    ADD CONSTRAINT object_registry_pkey PRIMARY KEY (id);


--
-- Name: object_registry_roid_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY object_registry
    ADD CONSTRAINT object_registry_roid_key UNIQUE (roid);


--
-- Name: object_state_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY object_state
    ADD CONSTRAINT object_state_pkey PRIMARY KEY (id);


--
-- Name: object_state_request_lock_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY object_state_request_lock
    ADD CONSTRAINT object_state_request_lock_pkey PRIMARY KEY (id);


--
-- Name: object_state_request_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY object_state_request
    ADD CONSTRAINT object_state_request_pkey PRIMARY KEY (id);


--
-- Name: poll_credit_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY poll_credit
    ADD CONSTRAINT poll_credit_pkey PRIMARY KEY (msgid);


--
-- Name: poll_credit_zone_limit_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY poll_credit_zone_limit
    ADD CONSTRAINT poll_credit_zone_limit_pkey PRIMARY KEY (zone);


--
-- Name: poll_eppaction_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY poll_eppaction
    ADD CONSTRAINT poll_eppaction_pkey PRIMARY KEY (msgid);


--
-- Name: poll_request_fee_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY poll_request_fee
    ADD CONSTRAINT poll_request_fee_pkey PRIMARY KEY (msgid);


--
-- Name: poll_statechange_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY poll_statechange
    ADD CONSTRAINT poll_statechange_pkey PRIMARY KEY (msgid);


--
-- Name: poll_techcheck_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY poll_techcheck
    ADD CONSTRAINT poll_techcheck_pkey PRIMARY KEY (msgid);


--
-- Name: price_list_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY price_list
    ADD CONSTRAINT price_list_pkey PRIMARY KEY (id);


--
-- Name: price_vat_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY price_vat
    ADD CONSTRAINT price_vat_pkey PRIMARY KEY (id);


--
-- Name: public_request_auth_identification_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY public_request_auth
    ADD CONSTRAINT public_request_auth_identification_key UNIQUE (identification);


--
-- Name: public_request_auth_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY public_request_auth
    ADD CONSTRAINT public_request_auth_pkey PRIMARY KEY (id);


--
-- Name: public_request_lock_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY public_request_lock
    ADD CONSTRAINT public_request_lock_pkey PRIMARY KEY (id);


--
-- Name: public_request_messages_map_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY public_request_messages_map
    ADD CONSTRAINT public_request_messages_map_pkey PRIMARY KEY (id);


--
-- Name: public_request_messages_map_public_request_id_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY public_request_messages_map
    ADD CONSTRAINT public_request_messages_map_public_request_id_key UNIQUE (public_request_id, message_archive_id);


--
-- Name: public_request_messages_map_public_request_id_key1; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY public_request_messages_map
    ADD CONSTRAINT public_request_messages_map_public_request_id_key1 UNIQUE (public_request_id, mail_archive_id);


--
-- Name: public_request_objects_map_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY public_request_objects_map
    ADD CONSTRAINT public_request_objects_map_pkey PRIMARY KEY (request_id);


--
-- Name: public_request_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY public_request
    ADD CONSTRAINT public_request_pkey PRIMARY KEY (id);


--
-- Name: public_request_state_request_map_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY public_request_state_request_map
    ADD CONSTRAINT public_request_state_request_map_pkey PRIMARY KEY (state_request_id);


--
-- Name: registrar_certification_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY registrar_certification
    ADD CONSTRAINT registrar_certification_pkey PRIMARY KEY (id);


--
-- Name: registrar_credit_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY registrar_credit
    ADD CONSTRAINT registrar_credit_pkey PRIMARY KEY (id);


--
-- Name: registrar_credit_transaction_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY registrar_credit_transaction
    ADD CONSTRAINT registrar_credit_transaction_pkey PRIMARY KEY (id);


--
-- Name: registrar_credit_unique_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY registrar_credit
    ADD CONSTRAINT registrar_credit_unique_key UNIQUE (registrar_id, zone_id);


--
-- Name: registrar_disconnect_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY registrar_disconnect
    ADD CONSTRAINT registrar_disconnect_pkey PRIMARY KEY (id);


--
-- Name: registrar_group_map_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY registrar_group_map
    ADD CONSTRAINT registrar_group_map_pkey PRIMARY KEY (id);


--
-- Name: registrar_group_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY registrar_group
    ADD CONSTRAINT registrar_group_pkey PRIMARY KEY (id);


--
-- Name: registrar_group_short_name_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY registrar_group
    ADD CONSTRAINT registrar_group_short_name_key UNIQUE (short_name);


--
-- Name: registrar_handle_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY registrar
    ADD CONSTRAINT registrar_handle_key UNIQUE (handle);


--
-- Name: registrar_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY registrar
    ADD CONSTRAINT registrar_pkey PRIMARY KEY (id);


--
-- Name: registraracl_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY registraracl
    ADD CONSTRAINT registraracl_pkey PRIMARY KEY (id);


--
-- Name: registrarinvoice_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY registrarinvoice
    ADD CONSTRAINT registrarinvoice_pkey PRIMARY KEY (id);


--
-- Name: reminder_contact_message_map_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY reminder_contact_message_map
    ADD CONSTRAINT reminder_contact_message_map_pkey PRIMARY KEY (reminder_date, contact_id);


--
-- Name: reminder_registrar_parameter_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY reminder_registrar_parameter
    ADD CONSTRAINT reminder_registrar_parameter_pkey PRIMARY KEY (registrar_id);


--
-- Name: request_data_epp_13_06_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY request_data_epp_13_06
    ADD CONSTRAINT request_data_epp_13_06_pkey PRIMARY KEY (id);


--
-- Name: request_data_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY request_data
    ADD CONSTRAINT request_data_pkey PRIMARY KEY (id);


--
-- Name: request_epp_13_06_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY request_epp_13_06
    ADD CONSTRAINT request_epp_13_06_pkey PRIMARY KEY (id);


--
-- Name: request_fee_parameter_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY request_fee_parameter
    ADD CONSTRAINT request_fee_parameter_pkey PRIMARY KEY (id);


--
-- Name: request_fee_registrar_parameter_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY request_fee_registrar_parameter
    ADD CONSTRAINT request_fee_registrar_parameter_pkey PRIMARY KEY (registrar_id);


--
-- Name: request_object_ref_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY request_object_ref
    ADD CONSTRAINT request_object_ref_pkey PRIMARY KEY (id);


--
-- Name: request_object_type_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY request_object_type
    ADD CONSTRAINT request_object_type_pkey PRIMARY KEY (id);


--
-- Name: request_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY request
    ADD CONSTRAINT request_pkey PRIMARY KEY (id);


--
-- Name: request_property_name_name_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY request_property_name
    ADD CONSTRAINT request_property_name_name_key UNIQUE (name);


--
-- Name: request_property_name_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY request_property_name
    ADD CONSTRAINT request_property_name_pkey PRIMARY KEY (id);


--
-- Name: request_property_value_epp_13_06_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY request_property_value_epp_13_06
    ADD CONSTRAINT request_property_value_epp_13_06_pkey PRIMARY KEY (id);


--
-- Name: request_property_value_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY request_property_value
    ADD CONSTRAINT request_property_value_pkey PRIMARY KEY (id);


--
-- Name: request_type_name_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY request_type
    ADD CONSTRAINT request_type_name_key UNIQUE (name, service_id);


--
-- Name: request_type_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY request_type
    ADD CONSTRAINT request_type_pkey PRIMARY KEY (id);


--
-- Name: result_code_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY result_code
    ADD CONSTRAINT result_code_pkey PRIMARY KEY (id);


--
-- Name: result_code_unique_code; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY result_code
    ADD CONSTRAINT result_code_unique_code UNIQUE (service_id, result_code);


--
-- Name: result_code_unique_name; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY result_code
    ADD CONSTRAINT result_code_unique_name UNIQUE (service_id, name);


--
-- Name: service_name_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY service
    ADD CONSTRAINT service_name_key UNIQUE (name);


--
-- Name: service_partition_postfix_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY service
    ADD CONSTRAINT service_partition_postfix_key UNIQUE (partition_postfix);


--
-- Name: service_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY service
    ADD CONSTRAINT service_pkey PRIMARY KEY (id);


--
-- Name: session_13_06_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY session_13_06
    ADD CONSTRAINT session_13_06_pkey PRIMARY KEY (id);


--
-- Name: session_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY session
    ADD CONSTRAINT session_pkey PRIMARY KEY (id);


--
-- Name: sms_archive_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY sms_archive
    ADD CONSTRAINT sms_archive_pkey PRIMARY KEY (id);


--
-- Name: user_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY "user"
    ADD CONSTRAINT user_pkey PRIMARY KEY (id);


--
-- Name: zone_fqdn_key; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY zone
    ADD CONSTRAINT zone_fqdn_key UNIQUE (fqdn);


--
-- Name: zone_ns_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY zone_ns
    ADD CONSTRAINT zone_ns_pkey PRIMARY KEY (id);


--
-- Name: zone_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY zone
    ADD CONSTRAINT zone_pkey PRIMARY KEY (id);


--
-- Name: zone_soa_pkey; Type: CONSTRAINT; Schema: public; Owner: fred; Tablespace:
--

ALTER TABLE ONLY zone_soa
    ADD CONSTRAINT zone_soa_pkey PRIMARY KEY (zone);


--
-- Name: contact_history_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX contact_history_id_idx ON contact_history USING btree (id);


--
-- Name: domain_contact_map_contactid_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX domain_contact_map_contactid_idx ON domain_contact_map USING btree (contactid);


--
-- Name: domain_contact_map_domainid_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX domain_contact_map_domainid_idx ON domain_contact_map USING btree (domainid);


--
-- Name: domain_contact_map_history_contactid_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX domain_contact_map_history_contactid_idx ON domain_contact_map_history USING btree (contactid);


--
-- Name: domain_contact_map_history_domainid_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX domain_contact_map_history_domainid_idx ON domain_contact_map_history USING btree (domainid);


--
-- Name: domain_exdate_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX domain_exdate_idx ON domain USING btree (exdate);


--
-- Name: domain_history_exdate_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX domain_history_exdate_idx ON domain_history USING btree (exdate);


--
-- Name: domain_history_historyid_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX domain_history_historyid_idx ON domain_history USING btree (historyid);


--
-- Name: domain_history_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX domain_history_id_idx ON domain_history USING btree (id);


--
-- Name: domain_history_nsset_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX domain_history_nsset_idx ON domain_history USING btree (nsset);


--
-- Name: domain_history_registrant_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX domain_history_registrant_idx ON domain_history USING btree (registrant);


--
-- Name: domain_history_zone_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX domain_history_zone_idx ON domain_history USING btree (zone);


--
-- Name: domain_nsset_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX domain_nsset_idx ON domain USING btree (nsset);


--
-- Name: domain_registrant_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX domain_registrant_idx ON domain USING btree (registrant);


--
-- Name: domain_zone_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX domain_zone_idx ON domain USING btree (zone);


--
-- Name: enumval_history_domainid_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX enumval_history_domainid_idx ON enumval_history USING btree (domainid);


--
-- Name: epp_info_buffer_content_registrar_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX epp_info_buffer_content_registrar_id_idx ON epp_info_buffer_content USING btree (registrar_id);


--
-- Name: genzone_domain_history_domain_hid_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX genzone_domain_history_domain_hid_idx ON genzone_domain_history USING btree (domain_hid);


--
-- Name: genzone_domain_history_domain_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX genzone_domain_history_domain_id_idx ON genzone_domain_history USING btree (domain_id);


--
-- Name: history_action_valid_from_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX history_action_valid_from_idx ON history USING btree (valid_from);


--
-- Name: history_next_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE UNIQUE INDEX history_next_idx ON history USING btree (next);


--
-- Name: history_request_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX history_request_id_idx ON history USING btree (request_id) WHERE (request_id IS NOT NULL);


--
-- Name: host_fqdn_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX host_fqdn_idx ON host USING btree (fqdn);


--
-- Name: host_history_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX host_history_id_idx ON host_history USING btree (id);


--
-- Name: host_history_nssetid_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX host_history_nssetid_idx ON host_history USING btree (nssetid);


--
-- Name: host_ipaddr_map_history_hostid_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX host_ipaddr_map_history_hostid_idx ON host_ipaddr_map_history USING btree (hostid);


--
-- Name: host_ipaddr_map_history_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX host_ipaddr_map_history_id_idx ON host_ipaddr_map_history USING btree (id);


--
-- Name: host_ipaddr_map_history_nssetid_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX host_ipaddr_map_history_nssetid_idx ON host_ipaddr_map_history USING btree (nssetid);


--
-- Name: host_ipaddr_map_hostid_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX host_ipaddr_map_hostid_idx ON host_ipaddr_map USING btree (hostid);


--
-- Name: host_ipaddr_map_nssetid_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX host_ipaddr_map_nssetid_idx ON host_ipaddr_map USING btree (nssetid);


--
-- Name: host_nsset_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX host_nsset_idx ON host USING btree (nssetid);


--
-- Name: invoice_credit_payment_map_ac_invoice_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX invoice_credit_payment_map_ac_invoice_id_idx ON invoice_credit_payment_map USING btree (ac_invoice_id);


--
-- Name: invoice_credit_payment_map_ad_invoice_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX invoice_credit_payment_map_ad_invoice_id_idx ON invoice_credit_payment_map USING btree (ad_invoice_id);


--
-- Name: invoice_operation_charge_map_invoice_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX invoice_operation_charge_map_invoice_id_idx ON invoice_operation_charge_map USING btree (invoice_id);


--
-- Name: invoice_operation_object_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX invoice_operation_object_id_idx ON invoice_operation USING btree (object_id);


--
-- Name: keyset_contact_map_contact_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX keyset_contact_map_contact_idx ON keyset_contact_map USING btree (contactid);


--
-- Name: keyset_contact_map_keyset_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX keyset_contact_map_keyset_idx ON keyset_contact_map USING btree (keysetid);


--
-- Name: letter_archive_batch_id; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX letter_archive_batch_id ON letter_archive USING btree (batch_id);


--
-- Name: mail_archive_crdate_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX mail_archive_crdate_idx ON mail_archive USING btree (crdate);


--
-- Name: mail_archive_status_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX mail_archive_status_idx ON mail_archive USING btree (status);


--
-- Name: mail_attachments_mailid_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX mail_attachments_mailid_idx ON mail_attachments USING btree (mailid);


--
-- Name: message_archive_comm_type_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX message_archive_comm_type_id_idx ON message_archive USING btree (comm_type_id);


--
-- Name: message_archive_crdate_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX message_archive_crdate_idx ON message_archive USING btree (crdate);


--
-- Name: message_archive_status_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX message_archive_status_id_idx ON message_archive USING btree (status_id);


--
-- Name: message_clid_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX message_clid_idx ON message USING btree (clid);


--
-- Name: message_seen_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX message_seen_idx ON message USING btree (clid, seen, crdate, exdate);


--
-- Name: notify_letters_letter_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX notify_letters_letter_id_idx ON notify_letters USING btree (letter_id);


--
-- Name: notify_letters_status_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX notify_letters_status_idx ON notify_letters USING btree (state_id);


--
-- Name: nsset_contact_map_contactid_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX nsset_contact_map_contactid_idx ON nsset_contact_map USING btree (contactid);


--
-- Name: nsset_contact_map_history_contactid_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX nsset_contact_map_history_contactid_idx ON nsset_contact_map_history USING btree (contactid);


--
-- Name: nsset_contact_map_history_nssetid_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX nsset_contact_map_history_nssetid_idx ON nsset_contact_map_history USING btree (nssetid);


--
-- Name: nsset_contact_map_nssetid_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX nsset_contact_map_nssetid_idx ON nsset_contact_map USING btree (nssetid);


--
-- Name: nsset_history_historyid_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX nsset_history_historyid_idx ON nsset_history USING btree (historyid);


--
-- Name: nsset_history_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX nsset_history_id_idx ON nsset_history USING btree (id);


--
-- Name: object_clid_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX object_clid_idx ON object USING btree (clid);


--
-- Name: object_history_clid_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX object_history_clid_idx ON object_history USING btree (clid);


--
-- Name: object_history_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX object_history_id_idx ON object_history USING btree (id);


--
-- Name: object_history_upid_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX object_history_upid_idx ON object_history USING btree (upid);


--
-- Name: object_registry_historyid_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX object_registry_historyid_idx ON object_registry USING btree (historyid);


--
-- Name: object_registry_name_3_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX object_registry_name_3_idx ON object_registry USING btree (name) WHERE (type = 3);


--
-- Name: object_registry_name_type_uniq; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE UNIQUE INDEX object_registry_name_type_uniq ON object_registry USING btree (name, type) WHERE (erdate IS NULL);


--
-- Name: object_registry_upper_name_1_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX object_registry_upper_name_1_idx ON object_registry USING btree (upper((name)::text)) WHERE (type = 1);


--
-- Name: object_registry_upper_name_2_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX object_registry_upper_name_2_idx ON object_registry USING btree (upper((name)::text)) WHERE (type = 2);


--
-- Name: object_registry_upper_name_4_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX object_registry_upper_name_4_idx ON object_registry USING btree (upper((name)::text)) WHERE (type = 4);


--
-- Name: object_state_now_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE UNIQUE INDEX object_state_now_idx ON object_state USING btree (object_id, state_id) WHERE (valid_to IS NULL);


--
-- Name: object_state_object_id_all_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX object_state_object_id_all_idx ON object_state USING btree (object_id);


--
-- Name: object_state_object_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX object_state_object_id_idx ON object_state USING btree (object_id) WHERE (valid_to IS NULL);


--
-- Name: object_state_valid_from_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX object_state_valid_from_idx ON object_state USING btree (valid_from);


--
-- Name: object_upid_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX object_upid_idx ON object USING btree (upid);


--
-- Name: poll_statechange_stateid_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX poll_statechange_stateid_idx ON poll_statechange USING btree (stateid);


--
-- Name: registrar_certification_valid_from_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX registrar_certification_valid_from_idx ON registrar_certification USING btree (valid_from);


--
-- Name: registrar_certification_valid_until_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX registrar_certification_valid_until_idx ON registrar_certification USING btree (valid_until);


--
-- Name: registrar_group_map_member_from_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX registrar_group_map_member_from_idx ON registrar_group_map USING btree (member_from);


--
-- Name: registrar_group_map_member_until_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX registrar_group_map_member_until_idx ON registrar_group_map USING btree (member_until);


--
-- Name: registrar_group_short_name_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX registrar_group_short_name_idx ON registrar_group USING btree (short_name);


--
-- Name: request_action_type_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_action_type_idx ON request USING btree (request_type_id);


--
-- Name: request_data_entry_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_data_entry_id_idx ON request_data USING btree (request_id);


--
-- Name: request_data_entry_time_begin_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_data_entry_time_begin_idx ON request_data USING btree (request_time_begin);


--
-- Name: request_data_epp_13_06_entry_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_data_epp_13_06_entry_id_idx ON request_data_epp_13_06 USING btree (request_id);


--
-- Name: request_data_epp_13_06_entry_time_begin_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_data_epp_13_06_entry_time_begin_idx ON request_data_epp_13_06 USING btree (request_time_begin);


--
-- Name: request_data_epp_13_06_is_response_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_data_epp_13_06_is_response_idx ON request_data_epp_13_06 USING btree (is_response);


--
-- Name: request_data_is_response_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_data_is_response_idx ON request_data USING btree (is_response);


--
-- Name: request_epp_13_06_action_type_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_epp_13_06_action_type_idx ON request_epp_13_06 USING btree (request_type_id);


--
-- Name: request_epp_13_06_monitoring_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_epp_13_06_monitoring_idx ON request_epp_13_06 USING btree (is_monitoring);


--
-- Name: request_epp_13_06_service_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_epp_13_06_service_idx ON request_epp_13_06 USING btree (service_id);


--
-- Name: request_epp_13_06_source_ip_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_epp_13_06_source_ip_idx ON request_epp_13_06 USING btree (source_ip);


--
-- Name: request_epp_13_06_time_begin_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_epp_13_06_time_begin_idx ON request_epp_13_06 USING btree (time_begin);


--
-- Name: request_epp_13_06_time_end_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_epp_13_06_time_end_idx ON request_epp_13_06 USING btree (time_end);


--
-- Name: request_epp_13_06_user_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_epp_13_06_user_id_idx ON request_epp_13_06 USING btree (user_id);


--
-- Name: request_epp_13_06_user_name_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_epp_13_06_user_name_idx ON request_epp_13_06 USING btree (user_name);


--
-- Name: request_monitoring_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_monitoring_idx ON request USING btree (is_monitoring);


--
-- Name: request_object_ref_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_object_ref_id_idx ON request_object_ref USING btree (request_id);


--
-- Name: request_object_ref_object_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_object_ref_object_id_idx ON request_object_ref USING btree (object_id);


--
-- Name: request_object_ref_object_type_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_object_ref_object_type_id_idx ON request_object_ref USING btree (object_type_id);


--
-- Name: request_object_ref_service_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_object_ref_service_id_idx ON request_object_ref USING btree (request_service_id);


--
-- Name: request_object_ref_time_begin_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_object_ref_time_begin_idx ON request_object_ref USING btree (request_time_begin);


--
-- Name: request_property_name_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_property_name_idx ON request_property_name USING btree (name);


--
-- Name: request_property_value_entry_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_property_value_entry_id_idx ON request_property_value USING btree (request_id);


--
-- Name: request_property_value_entry_time_begin_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_property_value_entry_time_begin_idx ON request_property_value USING btree (request_time_begin);


--
-- Name: request_property_value_epp_13_06_entry_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_property_value_epp_13_06_entry_id_idx ON request_property_value_epp_13_06 USING btree (request_id);


--
-- Name: request_property_value_epp_13_06_entry_time_begin_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_property_value_epp_13_06_entry_time_begin_idx ON request_property_value_epp_13_06 USING btree (request_time_begin);


--
-- Name: request_property_value_epp_13_06_name_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_property_value_epp_13_06_name_id_idx ON request_property_value_epp_13_06 USING btree (property_name_id);


--
-- Name: request_property_value_epp_13_06_output_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_property_value_epp_13_06_output_idx ON request_property_value_epp_13_06 USING btree (output);


--
-- Name: request_property_value_epp_13_06_parent_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_property_value_epp_13_06_parent_id_idx ON request_property_value_epp_13_06 USING btree (parent_id);


--
-- Name: request_property_value_epp_13_06_value_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_property_value_epp_13_06_value_idx ON request_property_value_epp_13_06 USING btree (value);


--
-- Name: request_property_value_name_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_property_value_name_id_idx ON request_property_value USING btree (property_name_id);


--
-- Name: request_property_value_output_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_property_value_output_idx ON request_property_value USING btree (output);


--
-- Name: request_property_value_parent_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_property_value_parent_id_idx ON request_property_value USING btree (parent_id);


--
-- Name: request_property_value_value_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_property_value_value_idx ON request_property_value USING btree (value);


--
-- Name: request_service_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_service_idx ON request USING btree (service_id);


--
-- Name: request_source_ip_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_source_ip_idx ON request USING btree (source_ip);


--
-- Name: request_time_begin_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_time_begin_idx ON request USING btree (time_begin);


--
-- Name: request_time_end_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_time_end_idx ON request USING btree (time_end);


--
-- Name: request_user_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_user_id_idx ON request USING btree (user_id);


--
-- Name: request_user_name_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX request_user_name_idx ON request USING btree (user_name);


--
-- Name: session_13_06_login_date_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX session_13_06_login_date_idx ON session_13_06 USING btree (login_date);


--
-- Name: session_13_06_name_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX session_13_06_name_idx ON session_13_06 USING btree (user_name);


--
-- Name: session_13_06_user_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX session_13_06_user_id_idx ON session_13_06 USING btree (user_id);


--
-- Name: session_login_date_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX session_login_date_idx ON session USING btree (login_date);


--
-- Name: session_user_id_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX session_user_id_idx ON session USING btree (user_id);


--
-- Name: session_user_name_idx; Type: INDEX; Schema: public; Owner: fred; Tablespace:
--

CREATE INDEX session_user_name_idx ON session USING btree (user_name);


--
-- Name: request_data_insert_function; Type: RULE; Schema: public; Owner: fred
--

CREATE RULE request_data_insert_function AS ON INSERT TO request_data DO INSTEAD SELECT tr_request_data(new.request_time_begin, new.request_service_id, new.request_monitoring, new.request_id, new.content, new.is_response) AS tr_request_data;


--
-- Name: request_insert_function; Type: RULE; Schema: public; Owner: fred
--

CREATE RULE request_insert_function AS ON INSERT TO request DO INSTEAD SELECT tr_request(new.id, new.time_begin, new.time_end, new.source_ip, new.service_id, new.request_type_id, new.session_id, new.user_name, new.user_id, new.is_monitoring) AS tr_request;


--
-- Name: request_object_ref_insert_function; Type: RULE; Schema: public; Owner: fred
--

CREATE RULE request_object_ref_insert_function AS ON INSERT TO request_object_ref DO INSTEAD SELECT tr_request_object_ref(new.id, new.request_time_begin, new.request_service_id, new.request_monitoring, new.request_id, new.object_type_id, new.object_id) AS tr_request_object_ref;


--
-- Name: request_property_value_insert_function; Type: RULE; Schema: public; Owner: fred
--

CREATE RULE request_property_value_insert_function AS ON INSERT TO request_property_value DO INSTEAD SELECT tr_request_property_value(new.request_time_begin, new.request_service_id, new.request_monitoring, new.id, new.request_id, new.property_name_id, new.value, new.output, new.parent_id) AS tr_request_property_value;


--
-- Name: session_insert_function; Type: RULE; Schema: public; Owner: fred
--

CREATE RULE session_insert_function AS ON INSERT TO session DO INSTEAD SELECT tr_session(new.id, new.user_name, new.user_id, new.login_date, new.logout_date) AS tr_session;


--
-- Name: trigger_cancel_registrar_group; Type: TRIGGER; Schema: public; Owner: fred
--

CREATE TRIGGER trigger_cancel_registrar_group
    AFTER UPDATE ON registrar_group
    FOR EACH ROW
    EXECUTE PROCEDURE cancel_registrar_group_check();


--
-- Name: trigger_domain; Type: TRIGGER; Schema: public; Owner: fred
--

CREATE TRIGGER trigger_domain
    AFTER INSERT OR DELETE OR UPDATE ON domain
    FOR EACH ROW
    EXECUTE PROCEDURE status_update_domain();


--
-- Name: trigger_domain_contact_map; Type: TRIGGER; Schema: public; Owner: fred
--

CREATE TRIGGER trigger_domain_contact_map
    AFTER INSERT OR DELETE OR UPDATE ON domain_contact_map
    FOR EACH ROW
    EXECUTE PROCEDURE status_update_contact_map();


--
-- Name: trigger_enumval; Type: TRIGGER; Schema: public; Owner: fred
--

CREATE TRIGGER trigger_enumval
    AFTER UPDATE ON enumval
    FOR EACH ROW
    EXECUTE PROCEDURE status_update_enumval();


--
-- Name: trigger_keyset_contact_map; Type: TRIGGER; Schema: public; Owner: fred
--

CREATE TRIGGER trigger_keyset_contact_map
    AFTER INSERT OR DELETE OR UPDATE ON keyset_contact_map
    FOR EACH ROW
    EXECUTE PROCEDURE status_update_contact_map();


--
-- Name: trigger_lock_object_state_request; Type: TRIGGER; Schema: public; Owner: fred
--

CREATE TRIGGER trigger_lock_object_state_request
    AFTER INSERT OR UPDATE ON object_state_request
    FOR EACH ROW
    EXECUTE PROCEDURE lock_object_state_request();


--
-- Name: trigger_lock_public_request; Type: TRIGGER; Schema: public; Owner: fred
--

CREATE TRIGGER trigger_lock_public_request
    AFTER INSERT OR UPDATE ON public_request
    FOR EACH ROW
    EXECUTE PROCEDURE lock_public_request();


--
-- Name: trigger_nsset_contact_map; Type: TRIGGER; Schema: public; Owner: fred
--

CREATE TRIGGER trigger_nsset_contact_map
    AFTER INSERT OR DELETE OR UPDATE ON nsset_contact_map
    FOR EACH ROW
    EXECUTE PROCEDURE status_update_contact_map();


--
-- Name: trigger_object_history; Type: TRIGGER; Schema: public; Owner: fred
--

CREATE TRIGGER trigger_object_history
    AFTER INSERT ON object_history
    FOR EACH ROW
    EXECUTE PROCEDURE object_history_insert();


--
-- Name: trigger_object_registry_update_history_rec; Type: TRIGGER; Schema: public; Owner: fred
--

CREATE TRIGGER trigger_object_registry_update_history_rec
    AFTER UPDATE ON object_registry
    FOR EACH ROW
    EXECUTE PROCEDURE object_registry_update_history_rec();


--
-- Name: trigger_object_state; Type: TRIGGER; Schema: public; Owner: fred
--

CREATE TRIGGER trigger_object_state
    AFTER INSERT OR UPDATE ON object_state
    FOR EACH ROW
    EXECUTE PROCEDURE status_update_object_state();


--
-- Name: trigger_object_state_hid; Type: TRIGGER; Schema: public; Owner: fred
--

CREATE TRIGGER trigger_object_state_hid
    BEFORE INSERT OR UPDATE ON object_state
    FOR EACH ROW
    EXECUTE PROCEDURE status_update_hid();


--
-- Name: trigger_registrar_certification; Type: TRIGGER; Schema: public; Owner: fred
--

CREATE TRIGGER trigger_registrar_certification
    AFTER INSERT OR UPDATE ON registrar_certification
    FOR EACH ROW
    EXECUTE PROCEDURE registrar_certification_life_check();


--
-- Name: trigger_registrar_credit_transaction; Type: TRIGGER; Schema: public; Owner: fred
--

CREATE TRIGGER trigger_registrar_credit_transaction
    AFTER INSERT OR DELETE OR UPDATE ON registrar_credit_transaction
    FOR EACH ROW
    EXECUTE PROCEDURE registrar_credit_change_lock();


--
-- Name: trigger_registrar_group_map; Type: TRIGGER; Schema: public; Owner: fred
--

CREATE TRIGGER trigger_registrar_group_map
    AFTER INSERT OR UPDATE ON registrar_group_map
    FOR EACH ROW
    EXECUTE PROCEDURE registrar_group_map_check();


--
-- Name: bank_account_bank_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY bank_account
    ADD CONSTRAINT bank_account_bank_code_fkey FOREIGN KEY (bank_code) REFERENCES enum_bank_code(code);


--
-- Name: bank_account_zone_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY bank_account
    ADD CONSTRAINT bank_account_zone_fkey FOREIGN KEY (zone) REFERENCES zone(id);


--
-- Name: bank_payment_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY bank_payment
    ADD CONSTRAINT bank_payment_account_id_fkey FOREIGN KEY (account_id) REFERENCES bank_account(id);


--
-- Name: bank_payment_registrar_credit_registrar_credit_transaction_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY bank_payment_registrar_credit_transaction_map
    ADD CONSTRAINT bank_payment_registrar_credit_registrar_credit_transaction_fkey FOREIGN KEY (registrar_credit_transaction_id) REFERENCES registrar_credit_transaction(id);


--
-- Name: bank_payment_registrar_credit_transaction__bank_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY bank_payment_registrar_credit_transaction_map
    ADD CONSTRAINT bank_payment_registrar_credit_transaction__bank_payment_id_fkey FOREIGN KEY (bank_payment_id) REFERENCES bank_payment(id);


--
-- Name: bank_payment_statement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY bank_payment
    ADD CONSTRAINT bank_payment_statement_id_fkey FOREIGN KEY (statement_id) REFERENCES bank_statement(id);


--
-- Name: bank_statement_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY bank_statement
    ADD CONSTRAINT bank_statement_account_id_fkey FOREIGN KEY (account_id) REFERENCES bank_account(id);


--
-- Name: bank_statement_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY bank_statement
    ADD CONSTRAINT bank_statement_file_id_fkey FOREIGN KEY (file_id) REFERENCES files(id);


--
-- Name: check_dependance_addictid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY check_dependance
    ADD CONSTRAINT check_dependance_addictid_fkey FOREIGN KEY (addictid) REFERENCES check_test(id);


--
-- Name: check_dependance_testid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY check_dependance
    ADD CONSTRAINT check_dependance_testid_fkey FOREIGN KEY (testid) REFERENCES check_test(id);


--
-- Name: check_nsset_nsset_hid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY check_nsset
    ADD CONSTRAINT check_nsset_nsset_hid_fkey FOREIGN KEY (nsset_hid) REFERENCES nsset_history(historyid);


--
-- Name: check_result_checkid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY check_result
    ADD CONSTRAINT check_result_checkid_fkey FOREIGN KEY (checkid) REFERENCES check_nsset(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: check_result_testid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY check_result
    ADD CONSTRAINT check_result_testid_fkey FOREIGN KEY (testid) REFERENCES check_test(id);


--
-- Name: contact_country_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY contact
    ADD CONSTRAINT contact_country_fkey FOREIGN KEY (country) REFERENCES enum_country(id);


--
-- Name: contact_history_country_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY contact_history
    ADD CONSTRAINT contact_history_country_fkey FOREIGN KEY (country) REFERENCES enum_country(id);


--
-- Name: contact_history_historyid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY contact_history
    ADD CONSTRAINT contact_history_historyid_fkey FOREIGN KEY (historyid) REFERENCES history(id);


--
-- Name: contact_history_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY contact_history
    ADD CONSTRAINT contact_history_id_fkey FOREIGN KEY (id) REFERENCES object_registry(id);


--
-- Name: contact_history_ssntype_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY contact_history
    ADD CONSTRAINT contact_history_ssntype_fkey FOREIGN KEY (ssntype) REFERENCES enum_ssntype(id);


--
-- Name: contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY contact
    ADD CONSTRAINT contact_id_fkey FOREIGN KEY (id) REFERENCES object(id);


--
-- Name: contact_ssntype_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY contact
    ADD CONSTRAINT contact_ssntype_fkey FOREIGN KEY (ssntype) REFERENCES enum_ssntype(id);


--
-- Name: dnskey_history_historyid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY dnskey_history
    ADD CONSTRAINT dnskey_history_historyid_fkey FOREIGN KEY (historyid) REFERENCES history(id);


--
-- Name: dnskey_keysetid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY dnskey
    ADD CONSTRAINT dnskey_keysetid_fkey FOREIGN KEY (keysetid) REFERENCES keyset(id) ON UPDATE CASCADE;


--
-- Name: dnssec_domainid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY dnssec
    ADD CONSTRAINT dnssec_domainid_fkey FOREIGN KEY (domainid) REFERENCES domain(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: domain_blacklist_creator_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY domain_blacklist
    ADD CONSTRAINT domain_blacklist_creator_fkey FOREIGN KEY (creator) REFERENCES "user"(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: domain_contact_map_contactid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY domain_contact_map
    ADD CONSTRAINT domain_contact_map_contactid_fkey FOREIGN KEY (contactid) REFERENCES contact(id) ON UPDATE CASCADE;


--
-- Name: domain_contact_map_domainid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY domain_contact_map
    ADD CONSTRAINT domain_contact_map_domainid_fkey FOREIGN KEY (domainid) REFERENCES domain(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: domain_contact_map_history_contactid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY domain_contact_map_history
    ADD CONSTRAINT domain_contact_map_history_contactid_fkey FOREIGN KEY (contactid) REFERENCES object_registry(id);


--
-- Name: domain_contact_map_history_domainid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY domain_contact_map_history
    ADD CONSTRAINT domain_contact_map_history_domainid_fkey FOREIGN KEY (domainid) REFERENCES object_registry(id);


--
-- Name: domain_contact_map_history_historyid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY domain_contact_map_history
    ADD CONSTRAINT domain_contact_map_history_historyid_fkey FOREIGN KEY (historyid) REFERENCES history(id);


--
-- Name: domain_history_historyid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY domain_history
    ADD CONSTRAINT domain_history_historyid_fkey FOREIGN KEY (historyid) REFERENCES history(id);


--
-- Name: domain_history_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY domain_history
    ADD CONSTRAINT domain_history_id_fkey FOREIGN KEY (id) REFERENCES object_registry(id);


--
-- Name: domain_history_zone_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY domain_history
    ADD CONSTRAINT domain_history_zone_fkey FOREIGN KEY (zone) REFERENCES zone(id);


--
-- Name: domain_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY domain
    ADD CONSTRAINT domain_id_fkey FOREIGN KEY (id) REFERENCES object(id);


--
-- Name: domain_keyset_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY domain
    ADD CONSTRAINT domain_keyset_fkey FOREIGN KEY (keyset) REFERENCES keyset(id);


--
-- Name: domain_nsset_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY domain
    ADD CONSTRAINT domain_nsset_fkey FOREIGN KEY (nsset) REFERENCES nsset(id);


--
-- Name: domain_registrant_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY domain
    ADD CONSTRAINT domain_registrant_fkey FOREIGN KEY (registrant) REFERENCES contact(id);


--
-- Name: domain_zone_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY domain
    ADD CONSTRAINT domain_zone_fkey FOREIGN KEY (zone) REFERENCES zone(id);


--
-- Name: dsrecord_history_historyid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY dsrecord_history
    ADD CONSTRAINT dsrecord_history_historyid_fkey FOREIGN KEY (historyid) REFERENCES history(id);


--
-- Name: dsrecord_keysetid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY dsrecord
    ADD CONSTRAINT dsrecord_keysetid_fkey FOREIGN KEY (keysetid) REFERENCES keyset(id) ON UPDATE CASCADE;


--
-- Name: enum_object_states_desc_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY enum_object_states_desc
    ADD CONSTRAINT enum_object_states_desc_state_id_fkey FOREIGN KEY (state_id) REFERENCES enum_object_states(id);


--
-- Name: enumval_domainid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY enumval
    ADD CONSTRAINT enumval_domainid_fkey FOREIGN KEY (domainid) REFERENCES domain(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: enumval_history_domainid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY enumval_history
    ADD CONSTRAINT enumval_history_domainid_fkey FOREIGN KEY (domainid) REFERENCES object_registry(id);


--
-- Name: enumval_history_historyid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY enumval_history
    ADD CONSTRAINT enumval_history_historyid_fkey FOREIGN KEY (historyid) REFERENCES history(id);


--
-- Name: epp_info_buffer_content_registrar_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY epp_info_buffer_content
    ADD CONSTRAINT epp_info_buffer_content_registrar_id_fkey FOREIGN KEY (registrar_id) REFERENCES registrar(id);


--
-- Name: epp_info_buffer_registrar_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY epp_info_buffer
    ADD CONSTRAINT epp_info_buffer_registrar_id_fkey FOREIGN KEY (registrar_id) REFERENCES registrar(id);


--
-- Name: epp_info_buffer_registrar_id_fkey1; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY epp_info_buffer
    ADD CONSTRAINT epp_info_buffer_registrar_id_fkey1 FOREIGN KEY (registrar_id, current) REFERENCES epp_info_buffer_content(registrar_id, id);


--
-- Name: files_filetype_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY files
    ADD CONSTRAINT files_filetype_fkey FOREIGN KEY (filetype) REFERENCES enum_filetype(id);


--
-- Name: genzone_domain_history_domain_hid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY genzone_domain_history
    ADD CONSTRAINT genzone_domain_history_domain_hid_fkey FOREIGN KEY (domain_hid) REFERENCES domain_history(historyid);


--
-- Name: genzone_domain_history_domain_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY genzone_domain_history
    ADD CONSTRAINT genzone_domain_history_domain_id_fkey FOREIGN KEY (domain_id) REFERENCES object_registry(id);


--
-- Name: genzone_domain_history_status_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY genzone_domain_history
    ADD CONSTRAINT genzone_domain_history_status_fkey FOREIGN KEY (status) REFERENCES genzone_domain_status(id);


--
-- Name: genzone_domain_history_zone_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY genzone_domain_history
    ADD CONSTRAINT genzone_domain_history_zone_id_fkey FOREIGN KEY (zone_id) REFERENCES zone(id);


--
-- Name: host_history_historyid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY host_history
    ADD CONSTRAINT host_history_historyid_fkey FOREIGN KEY (historyid) REFERENCES history(id);


--
-- Name: host_history_nssetid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY host_history
    ADD CONSTRAINT host_history_nssetid_fkey FOREIGN KEY (nssetid) REFERENCES object_registry(id);


--
-- Name: host_ipaddr_map_history_historyid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY host_ipaddr_map_history
    ADD CONSTRAINT host_ipaddr_map_history_historyid_fkey FOREIGN KEY (historyid) REFERENCES history(id);


--
-- Name: host_ipaddr_map_history_nssetid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY host_ipaddr_map_history
    ADD CONSTRAINT host_ipaddr_map_history_nssetid_fkey FOREIGN KEY (nssetid) REFERENCES object_registry(id);


--
-- Name: host_ipaddr_map_hostid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY host_ipaddr_map
    ADD CONSTRAINT host_ipaddr_map_hostid_fkey FOREIGN KEY (hostid) REFERENCES host(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: host_ipaddr_map_nssetid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY host_ipaddr_map
    ADD CONSTRAINT host_ipaddr_map_nssetid_fkey FOREIGN KEY (nssetid) REFERENCES nsset(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: host_nssetid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY host
    ADD CONSTRAINT host_nssetid_fkey FOREIGN KEY (nssetid) REFERENCES nsset(id) ON UPDATE CASCADE;


--
-- Name: invoice_credit_payment_map_ac_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY invoice_credit_payment_map
    ADD CONSTRAINT invoice_credit_payment_map_ac_invoice_id_fkey FOREIGN KEY (ac_invoice_id) REFERENCES invoice(id);


--
-- Name: invoice_credit_payment_map_ad_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY invoice_credit_payment_map
    ADD CONSTRAINT invoice_credit_payment_map_ad_invoice_id_fkey FOREIGN KEY (ad_invoice_id) REFERENCES invoice(id);


--
-- Name: invoice_file_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY invoice
    ADD CONSTRAINT invoice_file_fkey FOREIGN KEY (file) REFERENCES files(id);


--
-- Name: invoice_filexml_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY invoice
    ADD CONSTRAINT invoice_filexml_fkey FOREIGN KEY (filexml) REFERENCES files(id);


--
-- Name: invoice_generation_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY invoice_generation
    ADD CONSTRAINT invoice_generation_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES invoice(id);


--
-- Name: invoice_generation_registrar_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY invoice_generation
    ADD CONSTRAINT invoice_generation_registrar_id_fkey FOREIGN KEY (registrar_id) REFERENCES registrar(id);


--
-- Name: invoice_generation_zone_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY invoice_generation
    ADD CONSTRAINT invoice_generation_zone_id_fkey FOREIGN KEY (zone_id) REFERENCES zone(id);


--
-- Name: invoice_invoice_prefix_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY invoice
    ADD CONSTRAINT invoice_invoice_prefix_id_fkey FOREIGN KEY (invoice_prefix_id) REFERENCES invoice_prefix(id);


--
-- Name: invoice_mails_genid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY invoice_mails
    ADD CONSTRAINT invoice_mails_genid_fkey FOREIGN KEY (genid) REFERENCES invoice_generation(id);


--
-- Name: invoice_mails_invoiceid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY invoice_mails
    ADD CONSTRAINT invoice_mails_invoiceid_fkey FOREIGN KEY (invoiceid) REFERENCES invoice(id);


--
-- Name: invoice_mails_mailid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY invoice_mails
    ADD CONSTRAINT invoice_mails_mailid_fkey FOREIGN KEY (mailid) REFERENCES mail_archive(id);


--
-- Name: invoice_number_prefix_invoice_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY invoice_number_prefix
    ADD CONSTRAINT invoice_number_prefix_invoice_type_id_fkey FOREIGN KEY (invoice_type_id) REFERENCES invoice_type(id);


--
-- Name: invoice_number_prefix_zone_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY invoice_number_prefix
    ADD CONSTRAINT invoice_number_prefix_zone_id_fkey FOREIGN KEY (zone_id) REFERENCES zone(id);


--
-- Name: invoice_operation_ac_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY invoice_operation
    ADD CONSTRAINT invoice_operation_ac_invoice_id_fkey FOREIGN KEY (ac_invoice_id) REFERENCES invoice(id);


--
-- Name: invoice_operation_charge_map_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY invoice_operation_charge_map
    ADD CONSTRAINT invoice_operation_charge_map_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES invoice(id);


--
-- Name: invoice_operation_charge_map_invoice_operation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY invoice_operation_charge_map
    ADD CONSTRAINT invoice_operation_charge_map_invoice_operation_id_fkey FOREIGN KEY (invoice_operation_id) REFERENCES invoice_operation(id);


--
-- Name: invoice_operation_object_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY invoice_operation
    ADD CONSTRAINT invoice_operation_object_id_fkey FOREIGN KEY (object_id) REFERENCES object_registry(id);


--
-- Name: invoice_operation_operation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY invoice_operation
    ADD CONSTRAINT invoice_operation_operation_id_fkey FOREIGN KEY (operation_id) REFERENCES enum_operation(id);


--
-- Name: invoice_operation_registrar_credit_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY invoice_operation
    ADD CONSTRAINT invoice_operation_registrar_credit_transaction_id_fkey FOREIGN KEY (registrar_credit_transaction_id) REFERENCES registrar_credit_transaction(id);


--
-- Name: invoice_operation_registrar_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY invoice_operation
    ADD CONSTRAINT invoice_operation_registrar_id_fkey FOREIGN KEY (registrar_id) REFERENCES registrar(id);


--
-- Name: invoice_operation_zone_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY invoice_operation
    ADD CONSTRAINT invoice_operation_zone_id_fkey FOREIGN KEY (zone_id) REFERENCES zone(id);


--
-- Name: invoice_prefix_typ_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY invoice_prefix
    ADD CONSTRAINT invoice_prefix_typ_fkey FOREIGN KEY (typ) REFERENCES invoice_type(id);


--
-- Name: invoice_prefix_zone_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY invoice_prefix
    ADD CONSTRAINT invoice_prefix_zone_id_fkey FOREIGN KEY (zone_id) REFERENCES zone(id);


--
-- Name: invoice_registrar_credit_tran_registrar_credit_transaction_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY invoice_registrar_credit_transaction_map
    ADD CONSTRAINT invoice_registrar_credit_tran_registrar_credit_transaction_fkey FOREIGN KEY (registrar_credit_transaction_id) REFERENCES registrar_credit_transaction(id);


--
-- Name: invoice_registrar_credit_transaction_map_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY invoice_registrar_credit_transaction_map
    ADD CONSTRAINT invoice_registrar_credit_transaction_map_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES invoice(id);


--
-- Name: invoice_registrar_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY invoice
    ADD CONSTRAINT invoice_registrar_id_fkey FOREIGN KEY (registrar_id) REFERENCES registrar(id);


--
-- Name: invoice_zone_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY invoice
    ADD CONSTRAINT invoice_zone_id_fkey FOREIGN KEY (zone_id) REFERENCES zone(id);


--
-- Name: keyset_contact_map_contactid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY keyset_contact_map
    ADD CONSTRAINT keyset_contact_map_contactid_fkey FOREIGN KEY (contactid) REFERENCES contact(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: keyset_contact_map_history_contactid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY keyset_contact_map_history
    ADD CONSTRAINT keyset_contact_map_history_contactid_fkey FOREIGN KEY (contactid) REFERENCES object_registry(id);


--
-- Name: keyset_contact_map_history_historyid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY keyset_contact_map_history
    ADD CONSTRAINT keyset_contact_map_history_historyid_fkey FOREIGN KEY (historyid) REFERENCES history(id);


--
-- Name: keyset_contact_map_history_keysetid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY keyset_contact_map_history
    ADD CONSTRAINT keyset_contact_map_history_keysetid_fkey FOREIGN KEY (keysetid) REFERENCES object_registry(id);


--
-- Name: keyset_contact_map_keysetid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY keyset_contact_map
    ADD CONSTRAINT keyset_contact_map_keysetid_fkey FOREIGN KEY (keysetid) REFERENCES keyset(id) ON UPDATE CASCADE;


--
-- Name: keyset_history_historyid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY keyset_history
    ADD CONSTRAINT keyset_history_historyid_fkey FOREIGN KEY (historyid) REFERENCES history(id);


--
-- Name: keyset_history_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY keyset_history
    ADD CONSTRAINT keyset_history_id_fkey FOREIGN KEY (id) REFERENCES object_registry(id);


--
-- Name: keyset_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY keyset
    ADD CONSTRAINT keyset_id_fkey FOREIGN KEY (id) REFERENCES object(id);


--
-- Name: letter_archive_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY letter_archive
    ADD CONSTRAINT letter_archive_file_id_fkey FOREIGN KEY (file_id) REFERENCES files(id);


--
-- Name: letter_archive_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY letter_archive
    ADD CONSTRAINT letter_archive_id_fkey FOREIGN KEY (id) REFERENCES message_archive(id);


--
-- Name: mail_archive_mailtype_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY mail_archive
    ADD CONSTRAINT mail_archive_mailtype_fkey FOREIGN KEY (mailtype) REFERENCES mail_type(id);


--
-- Name: mail_attachments_attachid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY mail_attachments
    ADD CONSTRAINT mail_attachments_attachid_fkey FOREIGN KEY (attachid) REFERENCES files(id);


--
-- Name: mail_attachments_mailid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY mail_attachments
    ADD CONSTRAINT mail_attachments_mailid_fkey FOREIGN KEY (mailid) REFERENCES mail_archive(id);


--
-- Name: mail_handles_mailid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY mail_handles
    ADD CONSTRAINT mail_handles_mailid_fkey FOREIGN KEY (mailid) REFERENCES mail_archive(id);


--
-- Name: mail_templates_footer_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY mail_templates
    ADD CONSTRAINT mail_templates_footer_fkey FOREIGN KEY (footer) REFERENCES mail_footer(id);


--
-- Name: mail_type_template_map_templateid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY mail_type_template_map
    ADD CONSTRAINT mail_type_template_map_templateid_fkey FOREIGN KEY (templateid) REFERENCES mail_templates(id);


--
-- Name: mail_type_template_map_typeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY mail_type_template_map
    ADD CONSTRAINT mail_type_template_map_typeid_fkey FOREIGN KEY (typeid) REFERENCES mail_type(id);


--
-- Name: message_archive_comm_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY message_archive
    ADD CONSTRAINT message_archive_comm_type_id_fkey FOREIGN KEY (comm_type_id) REFERENCES comm_type(id);


--
-- Name: message_archive_message_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY message_archive
    ADD CONSTRAINT message_archive_message_type_id_fkey FOREIGN KEY (message_type_id) REFERENCES message_type(id);


--
-- Name: message_archive_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY message_archive
    ADD CONSTRAINT message_archive_status_id_fkey FOREIGN KEY (status_id) REFERENCES enum_send_status(id);


--
-- Name: message_clid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY message
    ADD CONSTRAINT message_clid_fkey FOREIGN KEY (clid) REFERENCES registrar(id) ON UPDATE CASCADE;


--
-- Name: message_contact_history_map_message_archive_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY message_contact_history_map
    ADD CONSTRAINT message_contact_history_map_message_archive_id_fkey FOREIGN KEY (message_archive_id) REFERENCES message_archive(id);


--
-- Name: message_msgtype_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY message
    ADD CONSTRAINT message_msgtype_fkey FOREIGN KEY (msgtype) REFERENCES messagetype(id);


--
-- Name: notify_letters_letter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY notify_letters
    ADD CONSTRAINT notify_letters_letter_id_fkey FOREIGN KEY (letter_id) REFERENCES letter_archive(id);


--
-- Name: notify_letters_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY notify_letters
    ADD CONSTRAINT notify_letters_state_id_fkey FOREIGN KEY (state_id) REFERENCES object_state(id);


--
-- Name: notify_request_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY notify_request
    ADD CONSTRAINT notify_request_message_id_fkey FOREIGN KEY (message_id) REFERENCES mail_archive(id);


--
-- Name: notify_statechange_mail_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY notify_statechange
    ADD CONSTRAINT notify_statechange_mail_id_fkey FOREIGN KEY (mail_id) REFERENCES mail_archive(id);


--
-- Name: notify_statechange_map_mail_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY notify_statechange_map
    ADD CONSTRAINT notify_statechange_map_mail_type_id_fkey FOREIGN KEY (mail_type_id) REFERENCES mail_type(id);


--
-- Name: notify_statechange_map_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY notify_statechange_map
    ADD CONSTRAINT notify_statechange_map_state_id_fkey FOREIGN KEY (state_id) REFERENCES enum_object_states(id);


--
-- Name: notify_statechange_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY notify_statechange
    ADD CONSTRAINT notify_statechange_state_id_fkey FOREIGN KEY (state_id) REFERENCES object_state(id);


--
-- Name: notify_statechange_type_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY notify_statechange
    ADD CONSTRAINT notify_statechange_type_fkey FOREIGN KEY (type) REFERENCES notify_statechange_map(id);


--
-- Name: nsset_contact_map_contactid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY nsset_contact_map
    ADD CONSTRAINT nsset_contact_map_contactid_fkey FOREIGN KEY (contactid) REFERENCES contact(id) ON UPDATE CASCADE;


--
-- Name: nsset_contact_map_history_contactid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY nsset_contact_map_history
    ADD CONSTRAINT nsset_contact_map_history_contactid_fkey FOREIGN KEY (contactid) REFERENCES object_registry(id);


--
-- Name: nsset_contact_map_history_historyid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY nsset_contact_map_history
    ADD CONSTRAINT nsset_contact_map_history_historyid_fkey FOREIGN KEY (historyid) REFERENCES history(id);


--
-- Name: nsset_contact_map_history_nssetid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY nsset_contact_map_history
    ADD CONSTRAINT nsset_contact_map_history_nssetid_fkey FOREIGN KEY (nssetid) REFERENCES object_registry(id);


--
-- Name: nsset_contact_map_nssetid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY nsset_contact_map
    ADD CONSTRAINT nsset_contact_map_nssetid_fkey FOREIGN KEY (nssetid) REFERENCES nsset(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: nsset_history_historyid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY nsset_history
    ADD CONSTRAINT nsset_history_historyid_fkey FOREIGN KEY (historyid) REFERENCES history(id);


--
-- Name: nsset_history_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY nsset_history
    ADD CONSTRAINT nsset_history_id_fkey FOREIGN KEY (id) REFERENCES object_registry(id);


--
-- Name: nsset_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY nsset
    ADD CONSTRAINT nsset_id_fkey FOREIGN KEY (id) REFERENCES object(id);


--
-- Name: object_clid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY object
    ADD CONSTRAINT object_clid_fkey FOREIGN KEY (clid) REFERENCES registrar(id);


--
-- Name: object_history_clid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY object_history
    ADD CONSTRAINT object_history_clid_fkey FOREIGN KEY (clid) REFERENCES registrar(id);


--
-- Name: object_history_historyid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY object_history
    ADD CONSTRAINT object_history_historyid_fkey FOREIGN KEY (historyid) REFERENCES history(id);


--
-- Name: object_history_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY object_history
    ADD CONSTRAINT object_history_id_fkey FOREIGN KEY (id) REFERENCES object_registry(id);


--
-- Name: object_history_upid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY object_history
    ADD CONSTRAINT object_history_upid_fkey FOREIGN KEY (upid) REFERENCES registrar(id);


--
-- Name: object_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY object
    ADD CONSTRAINT object_id_fkey FOREIGN KEY (id) REFERENCES object_registry(id);


--
-- Name: object_registry_crhistoryid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY object_registry
    ADD CONSTRAINT object_registry_crhistoryid_fkey FOREIGN KEY (crhistoryid) REFERENCES history(id);


--
-- Name: object_registry_crid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY object_registry
    ADD CONSTRAINT object_registry_crid_fkey FOREIGN KEY (crid) REFERENCES registrar(id);


--
-- Name: object_registry_historyid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY object_registry
    ADD CONSTRAINT object_registry_historyid_fkey FOREIGN KEY (historyid) REFERENCES history(id);


--
-- Name: object_state_object_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY object_state
    ADD CONSTRAINT object_state_object_id_fkey FOREIGN KEY (object_id) REFERENCES object_registry(id);


--
-- Name: object_state_ohid_from_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY object_state
    ADD CONSTRAINT object_state_ohid_from_fkey FOREIGN KEY (ohid_from) REFERENCES object_history(historyid);


--
-- Name: object_state_ohid_to_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY object_state
    ADD CONSTRAINT object_state_ohid_to_fkey FOREIGN KEY (ohid_to) REFERENCES object_history(historyid);


--
-- Name: object_state_request_lock_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY object_state_request_lock
    ADD CONSTRAINT object_state_request_lock_state_id_fkey FOREIGN KEY (state_id) REFERENCES enum_object_states(id);


--
-- Name: object_state_request_object_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY object_state_request
    ADD CONSTRAINT object_state_request_object_id_fkey FOREIGN KEY (object_id) REFERENCES object_registry(id);


--
-- Name: object_state_request_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY object_state_request
    ADD CONSTRAINT object_state_request_state_id_fkey FOREIGN KEY (state_id) REFERENCES enum_object_states(id);


--
-- Name: object_state_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY object_state
    ADD CONSTRAINT object_state_state_id_fkey FOREIGN KEY (state_id) REFERENCES enum_object_states(id);


--
-- Name: object_upid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY object
    ADD CONSTRAINT object_upid_fkey FOREIGN KEY (upid) REFERENCES registrar(id);


--
-- Name: poll_credit_msgid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY poll_credit
    ADD CONSTRAINT poll_credit_msgid_fkey FOREIGN KEY (msgid) REFERENCES message(id);


--
-- Name: poll_credit_zone_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY poll_credit
    ADD CONSTRAINT poll_credit_zone_fkey FOREIGN KEY (zone) REFERENCES zone(id);


--
-- Name: poll_credit_zone_limit_zone_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY poll_credit_zone_limit
    ADD CONSTRAINT poll_credit_zone_limit_zone_fkey FOREIGN KEY (zone) REFERENCES zone(id);


--
-- Name: poll_eppaction_msgid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY poll_eppaction
    ADD CONSTRAINT poll_eppaction_msgid_fkey FOREIGN KEY (msgid) REFERENCES message(id);


--
-- Name: poll_eppaction_objid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY poll_eppaction
    ADD CONSTRAINT poll_eppaction_objid_fkey FOREIGN KEY (objid) REFERENCES object_history(historyid);


--
-- Name: poll_request_fee_msgid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY poll_request_fee
    ADD CONSTRAINT poll_request_fee_msgid_fkey FOREIGN KEY (msgid) REFERENCES message(id);


--
-- Name: poll_statechange_msgid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY poll_statechange
    ADD CONSTRAINT poll_statechange_msgid_fkey FOREIGN KEY (msgid) REFERENCES message(id);


--
-- Name: poll_statechange_stateid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY poll_statechange
    ADD CONSTRAINT poll_statechange_stateid_fkey FOREIGN KEY (stateid) REFERENCES object_state(id);


--
-- Name: poll_techcheck_cnid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY poll_techcheck
    ADD CONSTRAINT poll_techcheck_cnid_fkey FOREIGN KEY (cnid) REFERENCES check_nsset(id);


--
-- Name: poll_techcheck_msgid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY poll_techcheck
    ADD CONSTRAINT poll_techcheck_msgid_fkey FOREIGN KEY (msgid) REFERENCES message(id);


--
-- Name: price_list_operation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY price_list
    ADD CONSTRAINT price_list_operation_id_fkey FOREIGN KEY (operation_id) REFERENCES enum_operation(id);


--
-- Name: price_list_zone_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY price_list
    ADD CONSTRAINT price_list_zone_id_fkey FOREIGN KEY (zone_id) REFERENCES zone(id);


--
-- Name: public_request_answer_email_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY public_request
    ADD CONSTRAINT public_request_answer_email_id_fkey FOREIGN KEY (answer_email_id) REFERENCES mail_archive(id);


--
-- Name: public_request_auth_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY public_request_auth
    ADD CONSTRAINT public_request_auth_id_fkey FOREIGN KEY (id) REFERENCES public_request(id);


--
-- Name: public_request_lock_request_type_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY public_request_lock
    ADD CONSTRAINT public_request_lock_request_type_fkey FOREIGN KEY (request_type) REFERENCES enum_public_request_type(id);


--
-- Name: public_request_messages_map_public_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY public_request_messages_map
    ADD CONSTRAINT public_request_messages_map_public_request_id_fkey FOREIGN KEY (public_request_id) REFERENCES public_request(id);


--
-- Name: public_request_objects_map_object_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY public_request_objects_map
    ADD CONSTRAINT public_request_objects_map_object_id_fkey FOREIGN KEY (object_id) REFERENCES object_registry(id);


--
-- Name: public_request_objects_map_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY public_request_objects_map
    ADD CONSTRAINT public_request_objects_map_request_id_fkey FOREIGN KEY (request_id) REFERENCES public_request(id);


--
-- Name: public_request_registrar_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY public_request
    ADD CONSTRAINT public_request_registrar_id_fkey FOREIGN KEY (registrar_id) REFERENCES registrar(id);


--
-- Name: public_request_state_request_map_block_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY public_request_state_request_map
    ADD CONSTRAINT public_request_state_request_map_block_request_id_fkey FOREIGN KEY (block_request_id) REFERENCES public_request(id);


--
-- Name: public_request_state_request_map_state_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY public_request_state_request_map
    ADD CONSTRAINT public_request_state_request_map_state_request_id_fkey FOREIGN KEY (state_request_id) REFERENCES object_state_request(id);


--
-- Name: public_request_state_request_map_unblock_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY public_request_state_request_map
    ADD CONSTRAINT public_request_state_request_map_unblock_request_id_fkey FOREIGN KEY (unblock_request_id) REFERENCES public_request(id);


--
-- Name: registrar_certification_eval_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY registrar_certification
    ADD CONSTRAINT registrar_certification_eval_file_id_fkey FOREIGN KEY (eval_file_id) REFERENCES files(id);


--
-- Name: registrar_certification_registrar_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY registrar_certification
    ADD CONSTRAINT registrar_certification_registrar_id_fkey FOREIGN KEY (registrar_id) REFERENCES registrar(id);


--
-- Name: registrar_country_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY registrar
    ADD CONSTRAINT registrar_country_fkey FOREIGN KEY (country) REFERENCES enum_country(id);


--
-- Name: registrar_credit_registrar_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY registrar_credit
    ADD CONSTRAINT registrar_credit_registrar_id_fkey FOREIGN KEY (registrar_id) REFERENCES registrar(id);


--
-- Name: registrar_credit_transaction_registrar_credit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY registrar_credit_transaction
    ADD CONSTRAINT registrar_credit_transaction_registrar_credit_id_fkey FOREIGN KEY (registrar_credit_id) REFERENCES registrar_credit(id);


--
-- Name: registrar_credit_zone_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY registrar_credit
    ADD CONSTRAINT registrar_credit_zone_id_fkey FOREIGN KEY (zone_id) REFERENCES zone(id);


--
-- Name: registrar_disconnect_registrarid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY registrar_disconnect
    ADD CONSTRAINT registrar_disconnect_registrarid_fkey FOREIGN KEY (registrarid) REFERENCES registrar(id);


--
-- Name: registrar_group_map_registrar_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY registrar_group_map
    ADD CONSTRAINT registrar_group_map_registrar_group_id_fkey FOREIGN KEY (registrar_group_id) REFERENCES registrar_group(id);


--
-- Name: registrar_group_map_registrar_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY registrar_group_map
    ADD CONSTRAINT registrar_group_map_registrar_id_fkey FOREIGN KEY (registrar_id) REFERENCES registrar(id);


--
-- Name: registraracl_registrarid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY registraracl
    ADD CONSTRAINT registraracl_registrarid_fkey FOREIGN KEY (registrarid) REFERENCES registrar(id);


--
-- Name: registrarinvoice_registrarid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY registrarinvoice
    ADD CONSTRAINT registrarinvoice_registrarid_fkey FOREIGN KEY (registrarid) REFERENCES registrar(id);


--
-- Name: registrarinvoice_zone_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY registrarinvoice
    ADD CONSTRAINT registrarinvoice_zone_fkey FOREIGN KEY (zone) REFERENCES zone(id);


--
-- Name: reminder_contact_message_map_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY reminder_contact_message_map
    ADD CONSTRAINT reminder_contact_message_map_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES object_registry(id);


--
-- Name: reminder_contact_message_map_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY reminder_contact_message_map
    ADD CONSTRAINT reminder_contact_message_map_message_id_fkey FOREIGN KEY (message_id) REFERENCES mail_archive(id);


--
-- Name: reminder_registrar_parameter_registrar_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY reminder_registrar_parameter
    ADD CONSTRAINT reminder_registrar_parameter_registrar_id_fkey FOREIGN KEY (registrar_id) REFERENCES registrar(id);


--
-- Name: request_data_epp_13_06_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY request_data_epp_13_06
    ADD CONSTRAINT request_data_epp_13_06_entry_id_fkey FOREIGN KEY (request_id) REFERENCES request_epp_13_06(id);


--
-- Name: request_data_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY request_data
    ADD CONSTRAINT request_data_request_id_fkey FOREIGN KEY (request_id) REFERENCES request(id);


--
-- Name: request_fee_parameter_zone_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY request_fee_parameter
    ADD CONSTRAINT request_fee_parameter_zone_id_fkey FOREIGN KEY (zone_id) REFERENCES zone(id);


--
-- Name: request_fee_registrar_parameter_registrar_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY request_fee_registrar_parameter
    ADD CONSTRAINT request_fee_registrar_parameter_registrar_id_fkey FOREIGN KEY (registrar_id) REFERENCES registrar(id);


--
-- Name: request_object_ref_object_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY request_object_ref
    ADD CONSTRAINT request_object_ref_object_type_id_fkey FOREIGN KEY (object_type_id) REFERENCES request_object_type(id);


--
-- Name: request_object_ref_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY request_object_ref
    ADD CONSTRAINT request_object_ref_request_id_fkey FOREIGN KEY (request_id) REFERENCES request(id);


--
-- Name: request_property_value_epp_13_06_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY request_property_value_epp_13_06
    ADD CONSTRAINT request_property_value_epp_13_06_entry_id_fkey FOREIGN KEY (request_id) REFERENCES request_epp_13_06(id);


--
-- Name: request_property_value_epp_13_06_name_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY request_property_value_epp_13_06
    ADD CONSTRAINT request_property_value_epp_13_06_name_id_fkey FOREIGN KEY (property_name_id) REFERENCES request_property_name(id);


--
-- Name: request_property_value_epp_13_06_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY request_property_value_epp_13_06
    ADD CONSTRAINT request_property_value_epp_13_06_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES request_property_value_epp_13_06(id);


--
-- Name: request_property_value_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY request_property_value
    ADD CONSTRAINT request_property_value_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES request_property_value(id);


--
-- Name: request_property_value_property_name_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY request_property_value
    ADD CONSTRAINT request_property_value_property_name_id_fkey FOREIGN KEY (property_name_id) REFERENCES request_property_name(id);


--
-- Name: request_property_value_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY request_property_value
    ADD CONSTRAINT request_property_value_request_id_fkey FOREIGN KEY (request_id) REFERENCES request(id);


--
-- Name: request_request_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY request
    ADD CONSTRAINT request_request_type_id_fkey FOREIGN KEY (request_type_id) REFERENCES request_type(id);


--
-- Name: request_result_code_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY request
    ADD CONSTRAINT request_result_code_id_fkey FOREIGN KEY (result_code_id) REFERENCES result_code(id);


--
-- Name: request_service_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY request
    ADD CONSTRAINT request_service_id_fkey FOREIGN KEY (service_id) REFERENCES service(id);


--
-- Name: request_type_service_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY request_type
    ADD CONSTRAINT request_type_service_id_fkey FOREIGN KEY (service_id) REFERENCES service(id);


--
-- Name: result_code_service_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY result_code
    ADD CONSTRAINT result_code_service_id_fkey FOREIGN KEY (service_id) REFERENCES service(id);


--
-- Name: sms_archive_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY sms_archive
    ADD CONSTRAINT sms_archive_id_fkey FOREIGN KEY (id) REFERENCES message_archive(id);


--
-- Name: zone_ns_zone_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY zone_ns
    ADD CONSTRAINT zone_ns_zone_fkey FOREIGN KEY (zone) REFERENCES zone(id);


--
-- Name: zone_soa_zone_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fred
--

ALTER TABLE ONLY zone_soa
    ADD CONSTRAINT zone_soa_zone_fkey FOREIGN KEY (zone) REFERENCES zone(id);


--
-- Name: public; Type: ACL; Schema: -; Owner: fred
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM fred;
GRANT ALL ON SCHEMA public TO fred;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--
