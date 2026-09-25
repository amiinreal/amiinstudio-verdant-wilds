-- Somali Airlines app schema.
-- Bookings are written only by the `airline` Edge Function (service role).
-- Customers read them through that function with a reference + last name,
-- or directly when the booking is linked to their account.

-- ---------- Profiles ----------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  first_name text not null default '',
  last_name text not null default '',
  phone text not null default '',
  loyalty_number text unique not null
    default 'XC' || lpad((floor(random() * 100000000))::int::text, 8, '0'),
  role text not null default 'customer' check (role in ('customer', 'agent', 'admin')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Read own profile" on public.profiles
  for select to authenticated using (id = (select auth.uid()));
create policy "Update own profile" on public.profiles
  for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- Customers may edit their name and phone, never their role.
revoke update on public.profiles from authenticated, anon;
grant update (first_name, last_name, phone) on public.profiles to authenticated;

create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, first_name, last_name, phone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'first_name', ''),
    coalesce(new.raw_user_meta_data ->> 'last_name', ''),
    coalesce(new.raw_user_meta_data ->> 'phone', '')
  );
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create function public.is_staff() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role in ('agent', 'admin')
  );
$$;

-- ---------- Bookings ----------

create table public.bookings (
  id uuid primary key,
  pnr text not null unique,
  status text not null check (status in ('held', 'pending_payment', 'confirmed', 'cancelled')),
  user_id uuid references auth.users (id) on delete set null,
  contact_email text not null,
  total_usd numeric(10, 2) not null,
  paid_usd numeric(10, 2) not null default 0,
  hold_expires_at timestamptz,
  first_departure date not null,
  data jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index bookings_user_idx on public.bookings (user_id);
create index bookings_departure_idx on public.bookings (first_departure);

-- One row per booked seat. The primary key is what stops double booking.
-- live_until is null for paid bookings and the hold expiry for unpaid ones.
create table public.booking_seats (
  flight_id text not null,
  seat text not null,
  booking_id uuid not null references public.bookings (id) on delete cascade,
  live_until timestamptz,
  primary key (flight_id, seat)
);

create index booking_seats_booking_idx on public.booking_seats (booking_id);

-- Seated passengers per flight, for inventory.
create table public.booking_flights (
  booking_id uuid not null references public.bookings (id) on delete cascade,
  flight_id text not null,
  cabin text not null check (cabin in ('economy', 'business')),
  pax int not null,
  live_until timestamptz,
  primary key (booking_id, flight_id)
);

create index booking_flights_flight_idx on public.booking_flights (flight_id);

alter table public.bookings enable row level security;
alter table public.booking_seats enable row level security;
alter table public.booking_flights enable row level security;

create policy "Owners and staff read bookings" on public.bookings
  for select to authenticated using (user_id = (select auth.uid()) or (select public.is_staff()));
create policy "Staff read seats" on public.booking_seats
  for select to authenticated using ((select public.is_staff()));
create policy "Staff read inventory" on public.booking_flights
  for select to authenticated using ((select public.is_staff()));

-- ---------- Flight operations ----------

-- Status, delays and gates, entered by the operations team.
create table public.flight_ops (
  flight_id text primary key,
  status text check (status in ('scheduled', 'on_time', 'delayed', 'boarding', 'departed', 'landed', 'cancelled')),
  delay_min int not null default 0,
  gate text,
  note text,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id)
);

alter table public.flight_ops enable row level security;

create policy "Anyone reads flight status" on public.flight_ops
  for select to anon, authenticated using (true);
create policy "Staff insert flight status" on public.flight_ops
  for insert to authenticated with check ((select public.is_staff()));
create policy "Staff update flight status" on public.flight_ops
  for update to authenticated using ((select public.is_staff())) with check ((select public.is_staff()));

-- ---------- Functions used by the Edge Function ----------

create function public.airline_save_booking(p jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid := (p ->> 'id')::uuid;
  v_status text := p ->> 'status';
  v_live timestamptz := case when p ->> 'status' = 'confirmed' then null else (p ->> 'holdExpiresAt')::timestamptz end;
  v_flight text;
  v_pax int;
  i int;
begin
  insert into public.bookings as b (id, pnr, status, user_id, contact_email, total_usd, paid_usd, hold_expires_at, first_departure, data)
  values (
    v_id,
    p ->> 'pnr',
    v_status,
    nullif(p ->> 'userId', '')::uuid,
    p -> 'contact' ->> 'email',
    (p -> 'price' ->> 'total')::numeric,
    (p ->> 'paid')::numeric,
    (p ->> 'holdExpiresAt')::timestamptz,
    (p -> 'segments' -> 0 -> 'flight' ->> 'date')::date,
    p
  )
  on conflict (id) do update set
    status = excluded.status,
    user_id = excluded.user_id,
    contact_email = excluded.contact_email,
    total_usd = excluded.total_usd,
    paid_usd = excluded.paid_usd,
    hold_expires_at = excluded.hold_expires_at,
    first_departure = excluded.first_departure,
    data = excluded.data,
    updated_at = now();

  delete from public.booking_seats where booking_id = v_id;
  delete from public.booking_flights where booking_id = v_id;

  if v_status = 'cancelled' then
    return;
  end if;

  select count(*) into v_pax
  from jsonb_array_elements(p -> 'passengers') x
  where x ->> 'type' <> 'infant';

  for i in 0 .. jsonb_array_length(p -> 'segments') - 1 loop
    v_flight := p -> 'segments' -> i -> 'flight' ->> 'id';

    insert into public.booking_flights (booking_id, flight_id, cabin, pax, live_until)
    values (v_id, v_flight, p -> 'segments' -> i ->> 'cabin', v_pax, v_live);

    -- Free seats from holds that ran out, then claim ours. A seat another live
    -- booking holds raises unique_violation, which the function reports as taken.
    delete from public.booking_seats s
    where s.flight_id = v_flight and s.live_until is not null and s.live_until < now();

    insert into public.booking_seats (flight_id, seat, booking_id, live_until)
    select v_flight, x -> 'seats' ->> i, v_id, v_live
    from jsonb_array_elements(p -> 'passengers') x
    where x -> 'seats' ->> i is not null;
  end loop;
end $$;

create function public.airline_taken_seats(p_flight_id text) returns setof text
language sql stable security definer set search_path = '' as $$
  select seat from public.booking_seats
  where flight_id = p_flight_id and (live_until is null or live_until > now());
$$;

create function public.airline_booked_counts(p_flight_ids text[])
returns table (flight_id text, cabin text, pax bigint)
language sql stable security definer set search_path = '' as $$
  select f.flight_id, f.cabin, sum(f.pax)
  from public.booking_flights f
  where f.flight_id = any (p_flight_ids) and (f.live_until is null or f.live_until > now())
  group by f.flight_id, f.cabin;
$$;

revoke execute on function public.airline_save_booking(jsonb) from public, anon, authenticated;
revoke execute on function public.airline_taken_seats(text) from public, anon, authenticated;
revoke execute on function public.airline_booked_counts(text[]) from public, anon, authenticated;
grant execute on function public.airline_save_booking(jsonb) to service_role;
grant execute on function public.airline_taken_seats(text) to service_role;
grant execute on function public.airline_booked_counts(text[]) to service_role;
