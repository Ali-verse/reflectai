-- =============================================================================
-- ReflectAI — Complete Database Setup Script
-- Target Supabase Project: yfubwuwhlkicnbvjgbjg
-- Safe, non-destructive, transaction-wrapped idempotent setup
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. Helper Functions
-- -----------------------------------------------------------------------------

-- updated_at trigger function
CREATE OR REPLACE FUNCTION public.tg_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- auto profile creation on auth.users signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(
      NEW.raw_user_meta_data->>'name',
      NEW.raw_user_meta_data->>'full_name',
      split_part(NEW.email, '@', 1)
    ),
    NEW.raw_user_meta_data->>'avatar_url'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Revoke direct execution permissions on internal functions from client roles
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.tg_set_updated_at() FROM PUBLIC, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 2. Tables & Schema Definitions
-- -----------------------------------------------------------------------------

-- profiles table
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- journal_entries table
CREATE TABLE IF NOT EXISTS public.journal_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL DEFAULT '',
  content TEXT NOT NULL DEFAULT '',
  mood TEXT,
  tags TEXT[] NOT NULL DEFAULT '{}',
  pinned BOOLEAN NOT NULL DEFAULT false,
  favorite BOOLEAN NOT NULL DEFAULT false,
  entry_date TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- mood_logs table
CREATE TABLE IF NOT EXISTS public.mood_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  mood TEXT NOT NULL,
  note TEXT,
  logged_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- habits table (with UNIQUE(id, user_id) for composite foreign key integrity)
CREATE TABLE IF NOT EXISTS public.habits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  emoji TEXT NOT NULL DEFAULT '✨',
  color TEXT NOT NULL DEFAULT 'emerald',
  target_per_week INT NOT NULL DEFAULT 7,
  archived BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT habits_id_user_id_key UNIQUE (id, user_id)
);

-- habit_logs table (enforcing tenant ownership via composite foreign key)
CREATE TABLE IF NOT EXISTS public.habit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  habit_id UUID NOT NULL,
  log_date DATE NOT NULL DEFAULT (now() AT TIME ZONE 'utc')::date,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT habit_logs_habit_id_log_date_key UNIQUE (habit_id, log_date),
  CONSTRAINT habit_logs_habit_user_fkey FOREIGN KEY (habit_id, user_id) REFERENCES public.habits(id, user_id) ON DELETE CASCADE
);

-- Ensure constraints exist even if tables were partially created previously
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'habits_id_user_id_key' AND conrelid = 'public.habits'::regclass
  ) THEN
    ALTER TABLE public.habits ADD CONSTRAINT habits_id_user_id_key UNIQUE (id, user_id);
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'habit_logs_habit_id_fkey' AND conrelid = 'public.habit_logs'::regclass
  ) THEN
    ALTER TABLE public.habit_logs DROP CONSTRAINT habit_logs_habit_id_fkey;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'habit_logs_habit_user_fkey' AND conrelid = 'public.habit_logs'::regclass
  ) THEN
    ALTER TABLE public.habit_logs ADD CONSTRAINT habit_logs_habit_user_fkey FOREIGN KEY (habit_id, user_id) REFERENCES public.habits(id, user_id) ON DELETE CASCADE;
  END IF;
END $$;

-- goals table
CREATE TABLE IF NOT EXISTS public.goals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  category TEXT NOT NULL DEFAULT 'Growth',
  progress INT NOT NULL DEFAULT 0,
  target_date DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- coach_messages table
CREATE TABLE IF NOT EXISTS public.coach_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user','assistant','system')),
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- 3. Indexes
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS je_user_date ON public.journal_entries(user_id, entry_date DESC);
CREATE INDEX IF NOT EXISTS ml_user_date ON public.mood_logs(user_id, logged_at DESC);
CREATE INDEX IF NOT EXISTS hl_user_date ON public.habit_logs(user_id, log_date DESC);
CREATE INDEX IF NOT EXISTS cm_user_date ON public.coach_messages(user_id, created_at);

-- -----------------------------------------------------------------------------
-- 4. Triggers
-- -----------------------------------------------------------------------------

-- profiles updated_at
DROP TRIGGER IF EXISTS profiles_updated ON public.profiles;
CREATE TRIGGER profiles_updated
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_set_updated_at();

-- journal_entries updated_at
DROP TRIGGER IF EXISTS je_updated ON public.journal_entries;
CREATE TRIGGER je_updated
  BEFORE UPDATE ON public.journal_entries
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_set_updated_at();

-- goals updated_at
DROP TRIGGER IF EXISTS g_updated ON public.goals;
CREATE TRIGGER g_updated
  BEFORE UPDATE ON public.goals
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_set_updated_at();

-- auth.users signup trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- -----------------------------------------------------------------------------
-- 5. Privileges (Principle of Least Privilege)
-- -----------------------------------------------------------------------------

-- Revoke all table access from unauthenticated public/anon roles
REVOKE ALL ON TABLE
  public.profiles,
  public.journal_entries,
  public.mood_logs,
  public.habits,
  public.habit_logs,
  public.goals,
  public.coach_messages
FROM PUBLIC, anon;

-- Grant standard CRUD permissions to authenticated application users
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
  public.profiles,
  public.journal_entries,
  public.mood_logs,
  public.habits,
  public.habit_logs,
  public.goals,
  public.coach_messages
TO authenticated;

-- Grant full administrative permissions to service_role
GRANT ALL ON TABLE
  public.profiles,
  public.journal_entries,
  public.mood_logs,
  public.habits,
  public.habit_logs,
  public.goals,
  public.coach_messages
TO service_role;

-- -----------------------------------------------------------------------------
-- 6. Row Level Security (RLS) & Policies
-- -----------------------------------------------------------------------------

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mood_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.habits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.habit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coach_messages ENABLE ROW LEVEL SECURITY;

-- profiles policies
DROP POLICY IF EXISTS "own profile read" ON public.profiles;
CREATE POLICY "own profile read"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "own profile upsert" ON public.profiles;
CREATE POLICY "own profile upsert"
  ON public.profiles FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "own profile update" ON public.profiles;
CREATE POLICY "own profile update"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

-- journal_entries policy
DROP POLICY IF EXISTS "own entries" ON public.journal_entries;
CREATE POLICY "own entries"
  ON public.journal_entries FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- mood_logs policy
DROP POLICY IF EXISTS "own moods" ON public.mood_logs;
CREATE POLICY "own moods"
  ON public.mood_logs FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- habits policy
DROP POLICY IF EXISTS "own habits" ON public.habits;
CREATE POLICY "own habits"
  ON public.habits FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- habit_logs policy
DROP POLICY IF EXISTS "own habit logs" ON public.habit_logs;
CREATE POLICY "own habit logs"
  ON public.habit_logs FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- goals policy
DROP POLICY IF EXISTS "own goals" ON public.goals;
CREATE POLICY "own goals"
  ON public.goals FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- coach_messages policy
DROP POLICY IF EXISTS "own coach" ON public.coach_messages;
CREATE POLICY "own coach"
  ON public.coach_messages FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- 7. Backfill Profiles for Existing Users
-- -----------------------------------------------------------------------------
-- Existing users who signed up before the database trigger was created
-- need their profile row inserted so the dashboard loads cleanly without errors.
INSERT INTO public.profiles (id, display_name, avatar_url)
SELECT
  id,
  COALESCE(
    raw_user_meta_data->>'name',
    raw_user_meta_data->>'full_name',
    split_part(email, '@', 1)
  ),
  raw_user_meta_data->>'avatar_url'
FROM auth.users
ON CONFLICT (id) DO NOTHING;

COMMIT;
