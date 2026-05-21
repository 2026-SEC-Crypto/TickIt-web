# TickIt API

TickIt is a backend API designed for a "Secure Physical Attendance & Ticket Validation System." This system integrates time-based constraints, geofencing, and identity verification to effectively prevent fraudulent behaviors such as proxy check-ins and GPS spoofing.

## System Requirements

- Ruby 3.x
- Bundler

## Installation and Setup

### Prerequisites
- Ruby 3.x
- Bundler
- Slim gem (for view rendering)
- Mailgun account (for email verification)

### Quick Start

1. Install dependencies:
```bash
bundle install
```

2. Configure environment:
```bash
cp config/secrets-example.yml config/secrets.yml
```
Edit `config/secrets.yml` with your database configuration if needed.

3. Set up databases:
```bash
bundle exec rake db:migrate
bundle exec rake db:seed
```

4. Start the server with both API and web UI:
```bash
bundle exec rackup -p 9292
```

The server will run at `http://localhost:9292`

### Accessing the Application

**Web UI (Authentication & Account Management):**
- Home: http://localhost:9292/home
- Login: http://localhost:9292/login
- Register: http://localhost:9292/register
- Account: http://localhost:9292/account (requires login)

**API Endpoints:**
- API Root: http://localhost:9292/api/v1
- Events: http://localhost:9292/api/v1/events
- Attendances: http://localhost:9292/api/v1/attendances
- Accounts: http://localhost:9292/api/v1/accounts
- Auth: http://localhost:9292/api/v1/auth

### Test Accounts (After Running Seeds)

The seed data includes test accounts with different roles. Use these for development:

```bash
# View available seed scripts
cat seeds/20260427_create_all.rb
```

To create custom test accounts via the web UI:
1. Navigate to http://localhost:9292/register
2. Enter email and password
3. Account created with default "member" role
4. To set admin/organizer role, update directly in database or use API

### Environment Variables

Configure these in your shell or `.env` file:

```bash
# Session encryption key (minimum 64 characters for security)
# For development, a default key is provided
# For production, generate a strong key:
# ruby -require 'securerandom' -e 'puts SecureRandom.random_bytes(32).unpack("H*")[0]'
export SESSION_KEY="your-secure-64-character-key-here-generated-with-securerandom"

# Database (optional, defaults to SQLite in db/local/)
export DATABASE_URL="sqlite://db/local/development.db"

# Environment
export RACK_ENV=development  # or production
```

**Generate a Secure Session Key (Production):**
```bash
ruby -e "require 'securerandom'; puts SecureRandom.hex(32)"
```

This generates a 64-character random hex string suitable for production use.

## Web Application Features

### Authentication & Sessions

The web UI provides user authentication with secure session management:

- **Registration:** Create new accounts at `/register`
- **Login:** Authenticate with email and password at `/login`
- **Session Management:** HTTP-only encrypted cookie-based sessions
- **Logout:** Securely clear session data
- **Account Overview:** View and manage your account at `/account`

### Role-Based Access Control (RBAC)

The system supports three user roles with hierarchical permissions:

#### Member (Default)
- View events
- Record attendance
- View own account

#### Organizer
- All member permissions
- Create and manage events
- View attendance records for their events

#### Admin
- All organizer permissions
- Manage user accounts
- View all events and attendances
- Access admin dashboard
- View security logs

### Navigation

The web UI includes role-aware navigation:

**Logged Out:**
- Home, Login, Register

**Logged In:**
- Home, Account (with email), Logout
- Admin/Organizer see additional admin features on account page

### Flash Messages

User feedback is provided via flash messages:
- ✅ **Success messages** (green) - Login, registration, logout
- ❌ **Error messages** (red) - Validation errors, access denied
- ⚠️ **Warning messages** (yellow) - Important notices
- ℹ️ **Info messages** (blue) - General information

### Testing the Web UI

1. **Register as Member:**
   - Go to http://localhost:9292/register
   - Enter email and password
   - Account created with "member" role

2. **Login:**
   - Go to http://localhost:9292/login
   - Enter credentials
   - View account page with member features

3. **Test Admin Features** (requires admin role):
   - Update account role to "admin" in database
   - Login and navigate to `/account`
   - See admin-only sections and features

4. **Try Unauthorized Actions:**
   - Login as member
   - Try to access admin features (returns 403)
   - Flash message explains access denied

## Database Tasks

### Database Folder Layout

This project intentionally uses a split database layout:

- `app/db/migrations/`: Sequel migration files (schema changes)
- `seeds/`: `sequel-seed` seed scripts using dated filenames such as `20260427_create_all.rb`
- `db/local/`: runtime SQLite database files (e.g. `development.db`, `test.db`)

This means `app/db` stores database code/data definitions, `seeds/` stores runnable seed scripts, and `db/local` stores generated database files.

### Seeding with sequel-seed

This project uses the `sequel-seed` gem for database seeding.

- Put seed scripts in the top-level `seeds/` folder using date-prefixed names, for example:
  - `seeds/20260427_create_all.rb`
- Define seed logic in a `run` method inside a `Sequel.seed(:development, :test)` (or multi-env) block.
- Run seeds with:

```bash
bundle exec rake db:seed
```

### Team setup (quick start)

For collaborators, setup is:

```bash
bundle install
rake db:migrate
rake db:seed
```

If a clean local reset is needed first, run:

```bash
rake db:drop
rake db:migrate
rake db:seed
```

View the status of your database:

```bash
# Check development database
RACK_ENV=development bundle exec rake db:status

# Check test database
RACK_ENV=test bundle exec rake db:status
```

## Testing

To run the test suite:

```bash
bundle exec rake spec
```

This will execute all tests including:
- **HAPPY Path Tests:** Verify successful API operations for events, attendances, accounts, and student event/course lookups
- **SAD Path Tests:** Verify proper error handling for non-existent resources, invalid JSON, and mass-assignment attempts

To run API specs only:

```bash
bundle exec rake api_spec
```

## Security

To check for known vulnerabilities in project dependencies:

```bash
bundle exec rake audit
```

This command will scan all gems in your `Gemfile.lock` and alert you to any known security vulnerabilities. Run this regularly as part of your development workflow.

## Code Quality

To check code style and quality issues using RuboCop:

```bash
bundle exec rake style
```

This will run all tests and audits, then check code style.

## Interactive Console

To run an interactive Pry console with the application loaded:

```bash
bundle exec rake console
```

## Available Rake Tasks

To view all available tasks:

```bash
bundle exec rake -T
```

## API Documentation

Base URL: `http://localhost:9292`

All endpoints return JSON responses with appropriate HTTP status codes.

### 1. Check System Status

**Endpoint:** `GET /`

**Description:** Used to verify if the API server is up and running.

**Response:** `200 OK`
```json
{
  "message": "TickIt API is up and running!"
}
```

### 2. Students

The API does not expose full student CRUD at the moment. Instead, it exposes student-attendance derived views.

#### 2.1 Get Events for a Student
**Endpoint:** `GET /api/v1/students/:student_id/events`

**Response:** `200 OK`
```json
{
  "student_id": "STU001",
  "events": [
    {
      "id": "event-uuid",
      "name": "Web Development Workshop",
      "location": "Room 101",
      "start_time": "2026-04-12T14:00:00Z",
      "end_time": "2026-04-12T15:00:00Z",
      "description": "Introduction to Web Dev",
      "created_at": "2026-04-12T10:30:00Z",
      "updated_at": "2026-04-12T10:30:00Z"
    }
  ]
}
```

#### 2.2 Get Courses for a Student
**Endpoint:** `GET /api/v1/students/:student_id/courses`

**Response:** `200 OK`
```json
{
  "student_id": "STU001",
  "courses": [
    {
      "id": "event-uuid",
      "name": "Database Design Course",
      "location": "Room 303",
      "start_time": "2026-04-12T14:00:00Z",
      "end_time": "2026-04-12T15:00:00Z",
      "description": "Relational Database Concepts",
      "created_at": "2026-04-12T10:30:00Z",
      "updated_at": "2026-04-12T10:30:00Z"
    }
  ]
}
```

### 3. Accounts

#### 3.1 Create an Account
**Endpoint:** `POST /api/v1/accounts`

**Request Body:**
```json
{
  "email": "new_user@example.com",
  "password": "super_secure_password_123",
  "role": "member"
}
```

**Response:** `201 Created`
```json
{
  "message": "Account created successfully",
  "account": {
    "id": "account-uuid",
    "email": "new_user@example.com",
    "role": "member"
  }
}
```

#### 3.2 Get an Account by ID
**Endpoint:** `GET /api/v1/accounts/:id`

**Response:** `200 OK`
```json
{
  "account": {
    "id": "account-uuid",
    "email": "search_me@example.com",
    "role": "member"
  }
}
```

**Error:** `404 Not Found`
```json
{
  "error": "Account not found"
}
```

### 4. Events

#### 4.1 Get All Events
**Endpoint:** `GET /api/v1/events`

**Response:** `200 OK`
```json
{
  "events": []
}
```

#### 4.2 Get Event by ID
**Endpoint:** `GET /api/v1/events/:id`

**Response:** `200 OK`
```json
{
  "event": {
    "id": "event-uuid",
    "name": "Web Development Workshop",
    "location": "Room 101",
    "start_time": "2026-04-12T14:00:00Z",
    "end_time": "2026-04-12T15:00:00Z",
    "description": "Introduction to Web Dev"
  }
}
```

**Error:** `404 Not Found`
```json
{
  "error": "Event not found"
}
```

#### 4.3 Create an Event
**Endpoint:** `POST /api/v1/events`

**Request Body:**
```json
{
  "name": "Security Seminar",
  "location": "Room 202",
  "start_time": "2026-04-12T16:00:00Z",
  "end_time": "2026-04-12T17:00:00Z",
  "description": "Application Security Basics"
}
```

**Response:** `201 Created`
```json
{
  "message": "Event created",
  "event": {
    "id": "event-uuid",
    "name": "Security Seminar",
    "location": "Room 202",
    "start_time": "2026-04-12T16:00:00Z",
    "end_time": "2026-04-12T17:00:00Z",
    "description": "Application Security Basics"
  }
}
```

**Error:** `400 Bad Request`
```json
{
  "error": "Missing required fields",
  "missing": ["start_time", "end_time"]
}
```

### 5. Attendance Records

#### 5.1 Get All Attendance Record IDs
**Endpoint:** `GET /api/v1/attendances`

**Response:** `200 OK`
```json
{
  "attendance_ids": [
    "attendance-uuid"
  ]
}
```

#### 5.2 Get Attendance Record by ID
**Endpoint:** `GET /api/v1/attendances/:id`

**Response:** `200 OK`
```json
{
  "id": "attendance-uuid",
  "student_id": "B10902000",
  "status": "present",
  "check_in_time": "2026-04-12T22:08:14+08:00",
  "event_id": "event-uuid"
}
```

**Error:** `404 Not Found`
```json
{
  "error": "Attendance record not found"
}
```

#### 5.3 Create an Attendance Record
**Endpoint:** `POST /api/v1/attendances`

**Request Body:**
```json
{
  "student_id": "STU001",
  "event_id": "event-uuid"
}
```

**Response:** `201 Created`
```json
{
  "message": "Attendance successfully recorded",
  "id": "attendance-uuid"
}
```

**Error:** `400 Bad Request`
```json
{
  "error": "Illegal mass assignment detected"
}
```

**Error:** `400 Bad Request`
```json
{
  "error": "Invalid JSON format"
}
```

**Error:** `404 Not Found`
```json
{
  "error": "No event available; create an event or pass event_id"
}
```




## Deploying and Managing on Heroku
To deploy to heroku, use the following command in terminal:

```sh
git push heroku main
```

### Viewing Logs on Heroku

To view the logs for your app on Heroku, use the following command in your terminal:

```sh
heroku logs --tail
```

This command will stream the logs in real time.

### Opening the App on Heroku

To open your deployed app in the browser, run:

```sh
heroku open -a sec-2026-tickit            
```

Or simply visit `https://sec-2026-tickit-319cbadd4290.herokuapp.com/` in your web browser.
```




