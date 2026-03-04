-- create table for users
-- cd C:\Users\alcaj\Documents\GitHub\Unify-Coursework\backend ; C:/Users/alcaj/Documents/GitHub/Unify-Coursework/.venv/Scripts/python.exe manage.py runserver
CREATE TABLE users(
    user_id SERIAL PRIMARY KEY,
    up_number VARCHAR(20) NOT NULL UNIQUE,
    admin_id INT, -- for admin users, this will be NULL for regular users 
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    opt_in_email BOOLEAN DEFAULT FALSE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
--intersection table 
CREATE TABLE membership (
    membership_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    society_id INT NOT NULL,
    role VARCHAR(50) NOT NULL,
        CHECK (role IN ('member', 'admin')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
)

-- create table for societies
CREATE TABLE society(
    society_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    category VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)

-- create table for polls
CREATE TABLE poll(
    poll_id SERIAL PRIMARY KEY,
    society_id INT NOT NULL,
    opens_at TIMESTAMP NOT NULL,
    closes_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
    FOREIGN KEY (society_id) REFERENCES society(society_id) ON DELETE CASCADE
)

-- create table for poll options
CREATE TABLE poll_option(
    option_id SERIAL PRIMARY KEY,
    poll_id INT NOT NULL,
    option_text VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (poll_id) REFERENCES poll(poll_id) ON DELETE CASCADE
)

-- create table for poll votes  
CREATE TABLE poll_vote(
    vote_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    poll_id INT NOT NULL,
    option_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (option_id) REFERENCES poll_option(option_id) ON DELETE CASCADE,
    FOREIGN KEY (ppoll_id) REFERENCES poll(poll_id) ON DELETE CASCADE,
    UNIQUE (user_id, option_id, ppoll_id)
)   

-- create table for reviews
CREATE TABLE review(
    review_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    society_id INT NOT NULL,
    rating INT CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (society_id) REFERENCES society(society_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
)   

--create table for users review reactions
CREATE TABLE review_reaction(
    reaction_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    review_id INT NOT NULL,
    reaction_type VARCHAR(20) NOT NULL CHECK (reaction_type IN ('like', 'dislike')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (review_id) REFERENCES review(review_id) ON DELETE CASCADE
) 

--create table for amin review responses 
CREATE TABLE review_response(
    response_id SERIAL PRIMARY KEY,
    review_id INT NOT NULL,
    society_id INT NOT NULL,
    admin_id INT NOT NULL,
    response_text TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (review_id) REFERENCES review(review_id) ON DELETE CASCADE,
    FOREIGN KEY (society_id) REFERENCES society(society_id) ON DELETE CASCADE,
    FOREIGN KEY (admin_id) REFERENCES users(user_id) ON DELETE CASCADE
)   

--helps to speed up quereis that filer by these entities, improving speed of application
INDEX idx_user_email ON users(email);
INDEX idx_society_name ON society(name);
INDEX idx_poll_society ON poll(society_id);
INDEX idx_poll_option_poll ON poll_option(poll_id);
INDEX idx_poll_vote_user ON poll_vote(user_id);
INDEX idx_poll_vote_option ON poll_vote(option_id);
INDEX idx_review_society ON review(society_id);
INDEX idx_review_user ON review(user_id);