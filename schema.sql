-- ====================================================================
-- SUPABASE / POSTGRESQL ARCHITECTURAL DATABASE SCHEMA
-- Music Streaming Cross-Platform App (Laguku / SoundSphere)
-- ====================================================================

-- 1. Enable UUID Extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. USERS PROFILE TABLE (Extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    is_premium BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. ARTISTS TABLE
CREATE TABLE IF NOT EXISTS public.artists (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    bio TEXT,
    avatar_url TEXT,
    cover_image_url TEXT,
    monthly_listeners INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. ALBUMS TABLE
CREATE TABLE IF NOT EXISTS public.albums (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    artist_id UUID REFERENCES public.artists(id) ON DELETE CASCADE,
    cover_image_url TEXT NOT NULL,
    release_date DATE,
    genre TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. SONGS TABLE
CREATE TABLE IF NOT EXISTS public.songs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    artist_id UUID REFERENCES public.artists(id) ON DELETE SET NULL,
    album_id UUID REFERENCES public.albums(id) ON DELETE SET NULL,
    duration INT NOT NULL, -- in seconds
    audio_url TEXT NOT NULL, -- Supabase Storage bucket URL
    cover_image_url TEXT,
    lyrics TEXT, -- LRC format or plain text
    genre TEXT NOT NULL DEFAULT 'Pop',
    play_count BIGINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. PLAYLISTS TABLE
CREATE TABLE IF NOT EXISTS public.playlists (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    cover_image_url TEXT,
    is_public BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. PLAYLIST_SONGS JUNCTION TABLE (Ordered via position index)
CREATE TABLE IF NOT EXISTS public.playlist_songs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    playlist_id UUID REFERENCES public.playlists(id) ON DELETE CASCADE,
    song_id UUID REFERENCES public.songs(id) ON DELETE CASCADE,
    position INT NOT NULL DEFAULT 0,
    added_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(playlist_id, song_id)
);

-- 8. USER FAVORITES (Liked Songs)
CREATE TABLE IF NOT EXISTS public.user_favorites (
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    song_id UUID REFERENCES public.songs(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, song_id)
);

-- 9. PLAYBACK HISTORY (Recently Played)
CREATE TABLE IF NOT EXISTS public.playback_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    song_id UUID REFERENCES public.songs(id) ON DELETE CASCADE,
    played_at TIMESTAMPTZ DEFAULT NOW(),
    progress_seconds INT DEFAULT 0
);

-- ====================================================================
-- INDEXES FOR FAST QUERYING & SEARCH
-- ====================================================================
CREATE INDEX IF NOT EXISTS idx_songs_title_trgm ON public.songs USING gin (title gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_songs_artist ON public.songs(artist_id);
CREATE INDEX IF NOT EXISTS idx_songs_genre ON public.songs(genre);
CREATE INDEX IF NOT EXISTS idx_playlist_songs_playlist ON public.playlist_songs(playlist_id, position);
CREATE INDEX IF NOT EXISTS idx_playback_history_user ON public.playback_history(user_id, played_at DESC);

-- ====================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ====================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.songs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.playlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.playlist_songs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_favorites ENABLE ROW LEVEL SECURITY;

-- Profiles: Anyone can view, only owner can update
CREATE POLICY "Public profiles are viewable by everyone" 
ON public.profiles FOR SELECT USING (true);

CREATE POLICY "Users can update own profile" 
ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Songs: Public read access
CREATE POLICY "Songs are viewable by everyone" 
ON public.songs FOR SELECT USING (true);

-- Playlists: Public playlists are viewable by all; private only by owner
CREATE POLICY "Public playlists are viewable by everyone" 
ON public.playlists FOR SELECT USING (is_public = true OR auth.uid() = user_id);

CREATE POLICY "Users can insert own playlists" 
ON public.playlists FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own playlists" 
ON public.playlists FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own playlists" 
ON public.playlists FOR DELETE USING (auth.uid() = user_id);

-- User Favorites: Only user can see & manage their favorites
CREATE POLICY "Users can view own favorites" 
ON public.user_favorites FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own favorites" 
ON public.user_favorites FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own favorites" 
ON public.user_favorites FOR DELETE USING (auth.uid() = user_id);

-- ====================================================================
-- SUPABASE STORAGE CONFIGURATION
-- Buckets:
-- 1. 'audio-tracks' (Private or Signed URLs / Public for streaming CDN)
-- 2. 'cover-art' (Public CDN for high-res artwork)
-- ====================================================================
INSERT INTO storage.buckets (id, name, public) 
VALUES ('audio-tracks', 'audio-tracks', true),
       ('cover-art', 'cover-art', true)
ON CONFLICT (id) DO NOTHING;
