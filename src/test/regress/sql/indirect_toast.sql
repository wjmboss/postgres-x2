
--
-- This test originally contains many RETURNING clauses.   Unfortunately, with ORDER BY extension, PGXC cannot
-- reproduce the order of the RETURNED rows.
--
-- Therefore, in this test, for reproducing the same result, RETURNING clause was omitted.
--
CREATE TABLE toasttest(descr text, cnt int DEFAULT 0, f1 text, f2 text);

INSERT INTO toasttest(descr, f1, f2) VALUES('two-compressed', repeat('1234567890',1000), repeat('1234567890',1000));
INSERT INTO toasttest(descr, f1, f2) VALUES('two-toasted', repeat('1234567890',30000), repeat('1234567890',50000));
INSERT INTO toasttest(descr, f1, f2) VALUES('one-compressed,one-null', NULL, repeat('1234567890',1000));
INSERT INTO toasttest(descr, f1, f2) VALUES('one-toasted,one-null', NULL, repeat('1234567890',50000));

-- check whether indirect tuples works on the most basic level
SELECT descr, substring(make_tuple_indirect(toasttest)::text, 1, 200) FROM toasttest ORDER BY 1,2;

-- modification without changing varlenas
-- UPDATE toasttest SET cnt = cnt +1 RETURNING substring(toasttest::text, 1, 200);
UPDATE toasttest SET cnt = cnt +1;

-- modification without modifying asigned value
-- UPDATE toasttest SET cnt = cnt +1, f1 = f1 RETURNING substring(toasttest::text, 1, 200);
UPDATE toasttest SET cnt = cnt +1, f1 = f1;

-- modification modifying, but effectively not changing
-- UPDATE toasttest SET cnt = cnt +1, f1 = f1||'' RETURNING substring(toasttest::text, 1, 200);
UPDATE toasttest SET cnt = cnt +1, f1 = f1||'';

-- UPDATE toasttest SET cnt = cnt +1, f1 = '-'||f1||'-' RETURNING substring(toasttest::text, 1, 200);
UPDATE toasttest SET cnt = cnt +1, f1 = '-'||f1||'-';

SELECT substring(toasttest::text, 1, 200) FROM toasttest ORDER BY 1;
-- check we didn't screw with main/toast tuple visiblity
VACUUM FREEZE toasttest;
SELECT substring(toasttest::text, 1, 200) FROM toasttest ORDER BY 1;

-- now create a trigger that forces all Datums to be indirect ones
CREATE FUNCTION update_using_indirect()
        RETURNS trigger
        LANGUAGE plpgsql AS $$
BEGIN
    NEW := make_tuple_indirect(NEW);
    RETURN NEW;
END$$;

CREATE TRIGGER toasttest_update_indirect
        BEFORE INSERT OR UPDATE
        ON toasttest
        FOR EACH ROW
        EXECUTE PROCEDURE update_using_indirect();

-- modification without changing varlenas
-- UPDATE toasttest SET cnt = cnt +1 RETURNING substring(toasttest::text, 1, 200);
UPDATE toasttest SET cnt = cnt +1;

-- modification without modifying asigned value
-- UPDATE toasttest SET cnt = cnt +1, f1 = f1 RETURNING substring(toasttest::text, 1, 200);
UPDATE toasttest SET cnt = cnt +1, f1 = f1;

-- modification modifying, but effectively not changing
-- UPDATE toasttest SET cnt = cnt +1, f1 = f1||'' RETURNING substring(toasttest::text, 1, 200);
UPDATE toasttest SET cnt = cnt +1, f1 = f1||'';

-- UPDATE toasttest SET cnt = cnt +1, f1 = '-'||f1||'-' RETURNING substring(toasttest::text, 1, 200);
UPDATE toasttest SET cnt = cnt +1, f1 = '-'||f1||'-';

INSERT INTO toasttest(descr, f1, f2) VALUES('one-toasted,one-null, via indirect', repeat('1234567890',30000), NULL);

SELECT substring(toasttest::text, 1, 200) FROM toasttest ORDER BY 1;
-- check we didn't screw with main/toast tuple visiblity
VACUUM FREEZE toasttest;
SELECT substring(toasttest::text, 1, 200) FROM toasttest ORDER BY 1;

DROP TABLE toasttest;
DROP FUNCTION update_using_indirect();
