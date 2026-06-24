create table if not exists profiles (
  id uuid references auth.users primary key,
  email text,
  display_name text,
  avatar_url text,
  created_at timestamptz default now()
);

create table if not exists translation_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users,
  session_id text,
  sign_label text not null,
  confidence float not null,
  recorded_at timestamptz not null,
  created_at timestamptz default now()
);

create table if not exists sign_feedback (
  id serial primary key,
  user_id uuid references auth.users,
  sign_label text not null,
  video_path text not null,
  submitted_at timestamptz not null,
  synced_at timestamptz default now()
);

alter table profiles enable row level security;
alter table translation_history enable row level security;
alter table sign_feedback enable row level security;

drop policy if exists "Users can manage own profile" on profiles;
drop policy if exists "Users can manage own translations" on translation_history;
drop policy if exists "Users can insert feedback" on sign_feedback;
drop policy if exists "Users can view own feedback" on sign_feedback;

create policy "Users can manage own profile"
on profiles for all
using (auth.uid() = id);

create policy "Users can manage own translations"
on translation_history for all
using (auth.uid() = user_id);

create policy "Users can insert feedback"
on sign_feedback for insert
with check (true);

create policy "Users can view own feedback"
on sign_feedback for select
using (auth.uid() = user_id or user_id is null);

insert into storage.buckets (id, name, public)
values ('sign-feedback-videos', 'sign-feedback-videos', false)
on conflict (id) do nothing;

drop policy if exists "Anyone can upload contribution videos" on storage.objects;
drop policy if exists "Users can view contribution videos" on storage.objects;

create policy "Anyone can upload contribution videos"
on storage.objects for insert
with check (bucket_id = 'sign-feedback-videos');

create policy "Users can view contribution videos"
on storage.objects for select
using (bucket_id = 'sign-feedback-videos');
