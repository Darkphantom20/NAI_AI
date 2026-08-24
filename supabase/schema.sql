create extension if not exists pgcrypto;

create table public.systems (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 120),
  created_at timestamptz not null default now()
);

create table public.knowledge_documents (
  id uuid primary key default gen_random_uuid(),
  system_id uuid not null references public.systems(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  file_name text not null check (char_length(file_name) between 1 and 255),
  storage_path text not null unique,
  content text not null default '',
  mime_type text not null,
  created_at timestamptz not null default now()
);

create table public.embed_tokens (
  id uuid primary key default gen_random_uuid(),
  system_id uuid not null references public.systems(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  token_hash text not null unique,
  allowed_origin text,
  expires_at timestamptz not null default (now() + interval '30 days'),
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.systems enable row level security;
alter table public.knowledge_documents enable row level security;
alter table public.embed_tokens enable row level security;

create policy "Owners manage their systems"
  on public.systems for all to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy "Owners manage their documents"
  on public.knowledge_documents for all to authenticated
  using (owner_id = auth.uid())
  with check (
    owner_id = auth.uid()
    and exists (
      select 1 from public.systems
      where systems.id = knowledge_documents.system_id
      and systems.owner_id = auth.uid()
    )
  );

create policy "Owners manage their tokens"
  on public.embed_tokens for all to authenticated
  using (owner_id = auth.uid())
  with check (
    owner_id = auth.uid()
    and exists (
      select 1 from public.systems
      where systems.id = embed_tokens.system_id
      and systems.owner_id = auth.uid()
    )
  );

insert into storage.buckets (id, name, public)
values ('knowledge', 'knowledge', false)
on conflict (id) do nothing;

create policy "Owners upload knowledge files"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'knowledge' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Owners read knowledge files"
  on storage.objects for select to authenticated
  using (bucket_id = 'knowledge' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Owners delete knowledge files"
  on storage.objects for delete to authenticated
  using (bucket_id = 'knowledge' and (storage.foldername(name))[1] = auth.uid()::text);

create index knowledge_documents_system_id_idx on public.knowledge_documents(system_id);
create index embed_tokens_hash_idx on public.embed_tokens(token_hash);
