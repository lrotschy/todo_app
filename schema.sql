CREATE TABLE lists (
  id serial PRIMARY KEY,
  name text UNIQUE NOT NULL
);

CREATE TABLE todos (
  id serial PRIMARY KEY,
  name text NOT NULL,
  list_id integer NOT NULL REFERENCES lists (id) NOT NULL,
  completed boolean NOT NULL DEFAULT false
);
