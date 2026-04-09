CREATE TABLE test_data (
    id SERIAL PRIMARY KEY,
    message VARCHAR(255) NOT NULL
);
INSERT INTO test_data (message) VALUES ('Hello from Postgres backend');
