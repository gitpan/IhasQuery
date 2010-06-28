BEGIN TRANSACTION;
CREATE TABLE haskey (anumber NUMERIC, aword TEXT, key_field INTEGER PRIMARY KEY);
INSERT INTO haskey VALUES(275.5,'excellent',1);
INSERT INTO haskey VALUES(15,'smaller',2);
CREATE TABLE stuff (integer NUMERIC, word TEXT);
COMMIT;
