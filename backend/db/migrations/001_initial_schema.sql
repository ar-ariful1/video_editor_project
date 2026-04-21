-- backend/db/migrations/001_initial_schema.sql
-- Complete PostgreSQL schema for Professional Video Editor

-- ─── Extensions ───────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";      -- for fuzzy text search
CREATE EXTENSION IF NOT EXISTS "btree_gin";     -- for multi-column GIN indexes

-- ─── ENUMS ────────────────────────────────────────────────────────────────────

CREATE TYPE auth_provider_type AS ENUM ('email', 'google', 'apple');
CREATE TYPE subscription_plan AS ENUM ('free', 'pro', 'premium');
CREATE TYPE subscription_status AS ENUM ('active', 'cancelled', 'expired', 'trial');
CREATE TYPE payment_provider AS ENUM ('stripe', 'apple_iap', 'google_play', 'revenuecat');
CREATE TYPE project_status AS ENUM ('draft', 'exported', 'deleted');
CREATE TYPE admin_role AS ENUM ('super_admin', 'template_manager', 'support', 'moderator');
CREATE TYPE export_quality AS ENUM ('720p', '1080p', '4k');
CREATE TYPE notification_type AS ENUM ('template_drop', 'feature_announcement', 'export_complete', 'subscription_expiry');

-- ─── SUBSCRIPTIONS (created first, referenced by users) ──────────────────────

CREATE TABLE subscriptions (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                 UUID,  -- FK added after users table
    plan                    subscription_plan NOT NULL DEFAULT 'free',
    status                  subscription_status NOT NULL DEFAULT 'active',
    provider                payment_provider,
    provider_subscription_id VARCHAR(255),
    current_period_start    TIMESTAMPTZ,
    current_period_end      TIMESTAMPTZ,
    trial_end               TIMESTAMPTZ,
    cancel_at_period_end    BOOLEAN DEFAULT FALSE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── USERS ────────────────────────────────────────────────────────────────────

CREATE TABLE users (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email                   VARCHAR(255) UNIQUE NOT NULL,
    display_name            VARCHAR(100),
    avatar_url              TEXT,
    auth_provider           auth_provider_type NOT NULL DEFAULT 'email',
    firebase_uid            VARCHAR(128) UNIQUE,
    password_hash           TEXT,                    -- only for email auth
    subscription_id         UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
    storage_used_bytes      BIGINT DEFAULT 0,
    export_count_today      INTEGER DEFAULT 0,
    ai_caption_seconds_today INTEGER DEFAULT 0,
    is_banned               BOOLEAN DEFAULT FALSE,
    ban_reason              TEXT,
    email_verified          BOOLEAN DEFAULT FALSE,
    onboarding_completed    BOOLEAN DEFAULT FALSE,
    preferred_resolution    VARCHAR(20) DEFAULT '1080p',
    timezone                VARCHAR(50) DEFAULT 'UTC',
    locale                  VARCHAR(10) DEFAULT 'en',
    last_login_at           TIMESTAMPTZ,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add FK from subscriptions → users
ALTER TABLE subscriptions ADD CONSTRAINT fk_subscriptions_user
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

-- ─── ADMINS ───────────────────────────────────────────────────────────────────

CREATE TABLE admins (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email                   VARCHAR(255) UNIQUE NOT NULL,
    password_hash           TEXT NOT NULL,           -- bcrypt cost=12
    totp_secret             TEXT,                    -- AES-256 encrypted
    role                    admin_role NOT NULL DEFAULT 'support',
    allowed_ips             TEXT[] DEFAULT '{}',     -- CIDR notation
    is_active               BOOLEAN DEFAULT TRUE,
    last_login_at           TIMESTAMPTZ,
    login_attempts          INTEGER DEFAULT 0,
    locked_until            TIMESTAMPTZ,
    created_by              UUID REFERENCES admins(id) ON DELETE SET NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed a super admin (password: change_me_immediately)
-- INSERT INTO admins (email, password_hash, role) VALUES ('admin@example.com', '$2b$12$...', 'super_admin');

-- ─── TEMPLATES ────────────────────────────────────────────────────────────────

CREATE TABLE templates (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name                    VARCHAR(255) NOT NULL,
    description             TEXT,
    category                VARCHAR(100) NOT NULL,
    tags                    TEXT[] DEFAULT '{}',
    template_json           JSONB NOT NULL,
    preview_url             TEXT,                    -- CDN .mp4
    thumbnail_url           TEXT,                    -- CDN .webp
    aspect_ratio            VARCHAR(10) DEFAULT '9:16',
    duration_seconds        FLOAT,
    slot_count              INTEGER DEFAULT 0,
    is_premium              BOOLEAN DEFAULT FALSE,
    price                   DECIMAL(10, 2) DEFAULT 0.00,
    download_count          INTEGER DEFAULT 0,
    use_count               INTEGER DEFAULT 0,
    rating_sum              FLOAT DEFAULT 0,
    rating_count            INTEGER DEFAULT 0,
    rating                  FLOAT GENERATED ALWAYS AS
                                (CASE WHEN rating_count > 0 THEN rating_sum / rating_count ELSE 0 END) STORED,
    is_approved             BOOLEAN DEFAULT FALSE,
    is_featured             BOOLEAN DEFAULT FALSE,
    is_trending             BOOLEAN DEFAULT FALSE,
    created_by              UUID REFERENCES admins(id) ON DELETE SET NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- Full-text search vector
    search_vector           TSVECTOR GENERATED ALWAYS AS (
        to_tsvector('english', name || ' ' || COALESCE(description, '') || ' ' || category || ' ' || array_to_string(tags, ' '))
    ) STORED
);

-- ─── PROJECTS ─────────────────────────────────────────────────────────────────

CREATE TABLE projects (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                 UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title                   VARCHAR(255) NOT NULL DEFAULT 'Untitled Project',
    thumbnail_url           TEXT,
    duration_seconds        FLOAT DEFAULT 0,
    resolution              JSONB NOT NULL DEFAULT '{"width": 1920, "height": 1080, "frameRate": 30}',
    timeline_json           JSONB,                   -- full serialized timeline
    template_id             UUID REFERENCES templates(id) ON DELETE SET NULL,
    size_bytes              BIGINT DEFAULT 0,
    status                  project_status NOT NULL DEFAULT 'draft',
    export_quality          export_quality,
    export_url              TEXT,                    -- CDN URL of exported video
    is_cloud_synced         BOOLEAN DEFAULT FALSE,
    last_synced_at          TIMESTAMPTZ,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── EXPORTS ──────────────────────────────────────────────────────────────────

CREATE TABLE exports (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id              UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    user_id                 UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status                  VARCHAR(20) DEFAULT 'queued',   -- queued|processing|done|failed
    quality                 export_quality NOT NULL,
    output_url              TEXT,
    file_size_bytes         BIGINT,
    duration_seconds        FLOAT,
    render_time_seconds     FLOAT,
    error_message           TEXT,
    watermarked             BOOLEAN DEFAULT FALSE,
    queued_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at              TIMESTAMPTZ,
    completed_at            TIMESTAMPTZ
);

-- ─── TEMPLATE PURCHASES ───────────────────────────────────────────────────────

CREATE TABLE template_purchases (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                 UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    template_id             UUID NOT NULL REFERENCES templates(id) ON DELETE CASCADE,
    price_paid              DECIMAL(10, 2) NOT NULL,
    provider                payment_provider,
    transaction_id          VARCHAR(255),
    purchased_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, template_id)
);

-- ─── TEMPLATE RATINGS ─────────────────────────────────────────────────────────

CREATE TABLE template_ratings (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                 UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    template_id             UUID NOT NULL REFERENCES templates(id) ON DELETE CASCADE,
    rating                  SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    review                  TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, template_id)
);

-- Auto-update template rating stats on insert/update
CREATE OR REPLACE FUNCTION update_template_rating()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE templates SET
        rating_sum = (SELECT COALESCE(SUM(rating), 0) FROM template_ratings WHERE template_id = NEW.template_id),
        rating_count = (SELECT COUNT(*) FROM template_ratings WHERE template_id = NEW.template_id)
    WHERE id = NEW.template_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_template_rating
AFTER INSERT OR UPDATE ON template_ratings
FOR EACH ROW EXECUTE FUNCTION update_template_rating();

-- ─── ASSETS ───────────────────────────────────────────────────────────────────

CREATE TABLE assets (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type                    VARCHAR(30) NOT NULL,    -- music | sticker | font | lut | effect | transition
    name                    VARCHAR(255) NOT NULL,
    url                     TEXT NOT NULL,           -- CDN URL
    thumbnail_url           TEXT,
    tags                    TEXT[] DEFAULT '{}',
    category                VARCHAR(100),
    duration_seconds        FLOAT,                   -- for music
    file_size_bytes         BIGINT,
    is_premium              BOOLEAN DEFAULT FALSE,
    is_active               BOOLEAN DEFAULT TRUE,
    download_count          INTEGER DEFAULT 0,
    created_by              UUID REFERENCES admins(id),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── NOTIFICATIONS ────────────────────────────────────────────────────────────

CREATE TABLE notifications (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                 UUID REFERENCES users(id) ON DELETE CASCADE,  -- NULL = broadcast
    type                    notification_type NOT NULL,
    title                   VARCHAR(255) NOT NULL,
    body                    TEXT,
    data                    JSONB DEFAULT '{}',
    is_read                 BOOLEAN DEFAULT FALSE,
    sent_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── AUDIT LOGS ───────────────────────────────────────────────────────────────

CREATE TABLE audit_logs (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    admin_id                UUID REFERENCES admins(id) ON DELETE SET NULL,
    action                  VARCHAR(100) NOT NULL,
    target_type             VARCHAR(50),             -- 'user' | 'template' | 'subscription' | etc.
    target_id               UUID,
    ip_address              VARCHAR(45),
    user_agent              TEXT,
    metadata                JSONB DEFAULT '{}',      -- {before, after} state
    timestamp               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── FEATURE FLAGS ────────────────────────────────────────────────────────────

CREATE TABLE feature_flags (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    key                     VARCHAR(100) UNIQUE NOT NULL,
    value                   JSONB NOT NULL DEFAULT 'true',
    description             TEXT,
    rollout_percentage      INTEGER DEFAULT 100 CHECK (rollout_percentage BETWEEN 0 AND 100),
    is_enabled              BOOLEAN DEFAULT TRUE,
    created_by              UUID REFERENCES admins(id),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── DAILY ANALYTICS ──────────────────────────────────────────────────────────

CREATE TABLE daily_analytics (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    date                    DATE NOT NULL UNIQUE,
    dau                     INTEGER DEFAULT 0,       -- daily active users
    new_signups             INTEGER DEFAULT 0,
    exports_720p            INTEGER DEFAULT 0,
    exports_1080p           INTEGER DEFAULT 0,
    exports_4k              INTEGER DEFAULT 0,
    ai_caption_jobs         INTEGER DEFAULT 0,
    ai_bg_removal_jobs      INTEGER DEFAULT 0,
    template_downloads      INTEGER DEFAULT 0,
    revenue_usd             DECIMAL(12, 2) DEFAULT 0,
    pro_subscribers         INTEGER DEFAULT 0,
    premium_subscribers     INTEGER DEFAULT 0,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── INDEXES ──────────────────────────────────────────────────────────────────

-- Users
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_firebase_uid ON users(firebase_uid);
CREATE INDEX idx_users_subscription ON users(subscription_id);
CREATE INDEX idx_users_created_at ON users(created_at DESC);

-- Projects
CREATE INDEX idx_projects_user_id ON projects(user_id);
CREATE INDEX idx_projects_status ON projects(status);
CREATE INDEX idx_projects_updated_at ON projects(updated_at DESC);

-- Templates
CREATE INDEX idx_templates_category ON templates(category);
CREATE INDEX idx_templates_is_premium ON templates(is_premium);
CREATE INDEX idx_templates_is_approved ON templates(is_approved);
CREATE INDEX idx_templates_search ON templates USING GIN(search_vector);
CREATE INDEX idx_templates_tags ON templates USING GIN(tags);
CREATE INDEX idx_templates_trending ON templates(is_trending, download_count DESC);
CREATE INDEX idx_templates_featured ON templates(is_featured, created_at DESC);

-- Exports
CREATE INDEX idx_exports_project_id ON exports(project_id);
CREATE INDEX idx_exports_user_id ON exports(user_id);
CREATE INDEX idx_exports_status ON exports(status);

-- Audit Logs
CREATE INDEX idx_audit_logs_admin_id ON audit_logs(admin_id);
CREATE INDEX idx_audit_logs_timestamp ON audit_logs(timestamp DESC);
CREATE INDEX idx_audit_logs_target ON audit_logs(target_type, target_id);

-- Subscriptions
CREATE INDEX idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_subscriptions_period_end ON subscriptions(current_period_end);

-- ─── UPDATE TRIGGERS ──────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_projects_updated_at BEFORE UPDATE ON projects FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_templates_updated_at BEFORE UPDATE ON templates FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_subscriptions_updated_at BEFORE UPDATE ON subscriptions FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_admins_updated_at BEFORE UPDATE ON admins FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ─── ROW LEVEL SECURITY ────────────────────────────────────────────────────────

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE exports ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE template_purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE template_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Users can only see their own data
CREATE POLICY users_self ON users FOR ALL USING (id = current_setting('app.user_id')::UUID);
CREATE POLICY projects_owner ON projects FOR ALL USING (user_id = current_setting('app.user_id')::UUID);
CREATE POLICY exports_owner ON exports FOR ALL USING (user_id = current_setting('app.user_id')::UUID);

COMMENT ON TABLE users IS 'App users — separate from admins';
COMMENT ON TABLE admins IS 'Admin staff — separate auth system, hidden login URL';
COMMENT ON TABLE templates IS 'Video templates with JSON slot definitions';
COMMENT ON TABLE projects IS 'User video projects with full timeline JSON';
COMMENT ON TABLE audit_logs IS 'All admin actions logged for security/compliance';
