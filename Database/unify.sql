-- Unify app schema (PostgreSQL)
--
-- IMPORTANT:
-- - This project is a Django app; run `python manage.py migrate` first.
-- - Django creates the `users` table (db_table='users') with primary key `id`.
-- - This SQL file creates the remaining domain tables that are not currently
--   represented as Django models/migrations.

-- create table for societies
CREATE TABLE IF NOT EXISTS society (
    society_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    category VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- intersection table
CREATE TABLE IF NOT EXISTS membership (
    membership_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    society_id INT NOT NULL,
    role VARCHAR(50) NOT NULL CHECK (role IN ('member', 'admin')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (society_id) REFERENCES society(society_id) ON DELETE CASCADE,
    UNIQUE (user_id, society_id)
);

-- create table for polls
CREATE TABLE IF NOT EXISTS poll (
    poll_id SERIAL PRIMARY KEY,
    society_id INT NOT NULL,
    opens_at TIMESTAMP NOT NULL,
    closes_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (society_id) REFERENCES society(society_id) ON DELETE CASCADE
);

-- create table for poll options
CREATE TABLE IF NOT EXISTS poll_option (
    option_id SERIAL PRIMARY KEY,
    poll_id INT NOT NULL,
    option_text VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (poll_id) REFERENCES poll(poll_id) ON DELETE CASCADE
);

-- create table for poll votes
CREATE TABLE IF NOT EXISTS poll_vote (
    vote_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    poll_id INT NOT NULL,
    option_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (poll_id) REFERENCES poll(poll_id) ON DELETE CASCADE,
    FOREIGN KEY (option_id) REFERENCES poll_option(option_id) ON DELETE CASCADE,
    UNIQUE (user_id, poll_id)
);

-- create table for reviews
CREATE TABLE IF NOT EXISTS review (
    review_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    society_id INT NOT NULL,
    rating INT CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (society_id) REFERENCES society(society_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- create table for user review reactions
CREATE TABLE IF NOT EXISTS review_reaction (
    reaction_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    review_id INT NOT NULL,
    reaction_type VARCHAR(20) NOT NULL CHECK (reaction_type IN ('like', 'dislike')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (review_id) REFERENCES review(review_id) ON DELETE CASCADE,
    UNIQUE (user_id, review_id)
);

-- create table for admin review responses
CREATE TABLE IF NOT EXISTS review_response (
    response_id SERIAL PRIMARY KEY,
    review_id INT NOT NULL,
    society_id INT NOT NULL,
    admin_id INT NOT NULL,
    response_text TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (review_id) REFERENCES review(review_id) ON DELETE CASCADE,
    FOREIGN KEY (society_id) REFERENCES society(society_id) ON DELETE CASCADE,
    FOREIGN KEY (admin_id) REFERENCES users(id) ON DELETE CASCADE
);

-- indexes (performance)
CREATE INDEX IF NOT EXISTS idx_user_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_society_name ON society(name);
CREATE INDEX IF NOT EXISTS idx_poll_society ON poll(society_id);
CREATE INDEX IF NOT EXISTS idx_poll_option_poll ON poll_option(poll_id);
CREATE INDEX IF NOT EXISTS idx_poll_vote_user ON poll_vote(user_id);
CREATE INDEX IF NOT EXISTS idx_poll_vote_option ON poll_vote(option_id);
CREATE INDEX IF NOT EXISTS idx_review_society ON review(society_id);
CREATE INDEX IF NOT EXISTS idx_review_user ON review(user_id);