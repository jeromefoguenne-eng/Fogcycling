-- =================================================================================
-- FOGCYCLING — SCHÉMA POSTGRESQL & POLITIQUES ROW LEVEL SECURITY (RLS) - PHASE 5
-- Conforme aux standards database-design-postgres-rls (3NF, B-Tree, RLS strict)
-- =================================================================================

-- 1. TABLE DES PROFILS ATHLÈTES
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL DEFAULT 'Cycliste Fogcycling',
    role TEXT NOT NULL DEFAULT 'athlete' CHECK (role IN ('athlete', 'admin')),
    weight_kg NUMERIC(5,2) NOT NULL DEFAULT 72.0 CHECK (weight_kg BETWEEN 35.0 AND 180.0),
    height_cm INTEGER NOT NULL DEFAULT 178 CHECK (height_cm BETWEEN 120 AND 230),
    ftp_watts INTEGER NOT NULL DEFAULT 200 CHECK (ftp_watts BETWEEN 80 AND 550),
    max_hr_bpm INTEGER NOT NULL DEFAULT 185 CHECK (max_hr_bpm BETWEEN 110 AND 230),
    resting_hr_bpm INTEGER NOT NULL DEFAULT 52 CHECK (resting_hr_bpm BETWEEN 30 AND 110),
    selected_bike_id TEXT NOT NULL DEFAULT 'fog_aero_orange',
    selected_jersey_id TEXT NOT NULL DEFAULT 'belgian_champ',
    xp_points INTEGER NOT NULL DEFAULT 1250,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. TABLE DE L'HISTORIQUE DES SORTIES & MÉTRIQUES PHYSIOLOGIQUES (WKO5 / STRAVA)
CREATE TABLE IF NOT EXISTS public.ride_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    route_id TEXT NOT NULL,
    route_name TEXT NOT NULL,
    duration_seconds INTEGER NOT NULL CHECK (duration_seconds > 0),
    distance_meters NUMERIC(10,2) NOT NULL DEFAULT 0,
    elevation_gain_meters INTEGER NOT NULL DEFAULT 0,
    avg_watts INTEGER NOT NULL DEFAULT 0,
    normalized_power_watts INTEGER NOT NULL DEFAULT 0,
    max_watts INTEGER NOT NULL DEFAULT 0,
    avg_cadence_rpm INTEGER NOT NULL DEFAULT 0,
    avg_hr_bpm INTEGER,
    intensity_factor NUMERIC(4,2) NOT NULL DEFAULT 0.0,
    training_stress_score NUMERIC(6,1) NOT NULL DEFAULT 0.0,
    tcx_payload TEXT,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ride_activities_user_date
    ON public.ride_activities (user_id, recorded_at DESC);

-- 3. TABLE D'AUDIT DE SÉCURITÉ & ADMINISTRATION
CREATE TABLE IF NOT EXISTS public.security_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    event_type TEXT NOT NULL,
    severity TEXT NOT NULL CHECK (severity IN ('INFO', 'WARN', 'CRITICAL')),
    details JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =================================================================================
-- ACTIVATION DU ROW LEVEL SECURITY (RLS - ZERO TRUST)
-- =================================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ride_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.security_audit_logs ENABLE ROW LEVEL SECURITY;

-- Politiques Profiles : Lecture/Modification de son propre profil uniquement (ou Admin)
CREATE POLICY "Users can view own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id OR EXISTS (
        SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
    ));

CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Politiques Ride Activities : Isolation stricte par athlète
CREATE POLICY "Athletes can view own rides"
    ON public.ride_activities FOR SELECT
    USING (auth.uid() = user_id OR EXISTS (
        SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
    ));

CREATE POLICY "Athletes can insert own rides"
    ON public.ride_activities FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Politiques Audit Logs : Réservé exclusivement aux administrateurs vérifiés
CREATE POLICY "Only admins can view security audit logs"
    ON public.security_audit_logs FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
    ));
