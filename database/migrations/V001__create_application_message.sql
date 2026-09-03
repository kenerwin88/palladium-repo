CREATE TABLE application_message (
    message_key text PRIMARY KEY,
    message_text text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE application_metadata (
    metadata_key text PRIMARY KEY,
    metadata_value text NOT NULL
);

INSERT INTO application_message (message_key, message_text)
VALUES ('home', 'Your trunk, application, and schema are healthy and ready to ship.');

INSERT INTO application_metadata (metadata_key, metadata_value)
VALUES ('schema_contract_version', '001');
