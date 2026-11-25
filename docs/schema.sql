-- IKONic Supabase schema. Run in Supabase SQL Editor. Designed for RLS and live subscriptions.
create extension if not exists pgcrypto;
create table if not exists profiles(id uuid primary key references auth.users on delete cascade, full_name text, role text not null default 'customer' check(role in ('admin','manager','staff','customer')), created_at timestamptz not null default now());
create table if not exists locations(id text primary key, name text not null, kind text not null default 'store', city text not null);
create table if not exists suppliers(id text primary key, name text not null, contact_name text, email text, phone text, lead_days int not null default 14, payment_terms int not null default 30, created_at timestamptz not null default now());
create table if not exists customers(id text primary key, name text not null, email text, phone text, loyalty_points int not null default 0, created_at timestamptz not null default now());
create table if not exists items(id text primary key, sku text unique not null, barcode text unique not null, name text not null, category text not null, description text, cost numeric(12,2) not null, price numeric(12,2) not null, lead_days int not null default 14, reorder_point int not null default 5, supplier_id text references suppliers, is_parent boolean not null default false, emoji text, created_at timestamptz not null default now());
create table if not exists bom(parent_id text references items on delete cascade, component_id text references items, qty_per numeric(12,3) not null, primary key(parent_id,component_id));
create table if not exists inventory(item_id text references items on delete cascade, location_id text references locations, qty int not null default 0, avg_cost numeric(12,2) not null default 0, primary key(item_id,location_id));
create table if not exists inventory_events(id uuid primary key default gen_random_uuid(), item_id text references items, location_id text references locations, qty_delta int not null, reason text not null, ref_type text, ref_id text, actor uuid references auth.users, created_at timestamptz not null default now());
create table if not exists sales_orders(id text primary key, customer_id text references customers, location_id text references locations, status text not null default 'Order Placed', channel text not null default 'POS', subtotal numeric(12,2) not null default 0, tax numeric(12,2) not null default 0, discount numeric(12,2) not null default 0, total numeric(12,2) not null default 0, cogs numeric(12,2) not null default 0, created_at timestamptz not null default now(), closed_at timestamptz);
create table if not exists sales_lines(id uuid primary key default gen_random_uuid(), order_id text references sales_orders on delete cascade, item_id text references items, qty int not null, unit_price numeric(12,2) not null, unit_cost numeric(12,2) not null, returned_qty int not null default 0);
create table if not exists purchase_orders(id text primary key, supplier_id text references suppliers, location_id text references locations, status text not null default 'Order Sent', ordered_at timestamptz not null default now(), expected_at date, received_at timestamptz, payment_due date, paid numeric(12,2) not null default 0, total numeric(12,2) not null default 0);
create table if not exists purchase_lines(id uuid primary key default gen_random_uuid(), po_id text references purchase_orders on delete cascade, item_id text references items, qty_ordered int not null, qty_received int not null default 0, unit_cost numeric(12,2) not null);
create table if not exists production_orders(id text primary key, item_id text references items, location_id text references locations, qty_started int not null, qty_good int not null default 0, qty_scrap int not null default 0, scrap_reason text, status text not null default 'Planned', started_at timestamptz, finished_at timestamptz, unit_cost numeric(12,2));
create table if not exists returns(id text primary key, order_id text references sales_orders, item_id text references items, location_id text references locations, qty int not null, reason text not null, disposition text not null, refund numeric(12,2) not null, created_at timestamptz not null default now());
create table if not exists transfers(id text primary key, item_id text references items, from_location text references locations, to_location text references locations, qty int not null, status text not null default 'In Transit', created_at timestamptz not null default now(), received_at timestamptz);
create table if not exists settings(key text primary key, value numeric not null);
create table if not exists audit_log(id uuid primary key default gen_random_uuid(), actor uuid references auth.users, action text not null, entity text not null, entity_id text, created_at timestamptz not null default now());
create or replace function ikon_is_staff() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from profiles where id=auth.uid() and role in ('admin','manager','staff')) $$;
do $$ declare t text; begin foreach t in array array['profiles','locations','suppliers','customers','items','bom','inventory','inventory_events','sales_orders','sales_lines','purchase_orders','purchase_lines','production_orders','returns','transfers','settings','audit_log'] loop execute format('alter table %I enable row level security',t); execute format('drop policy if exists %I on %I','ikon_read_'||t,t); execute format('create policy %I on %I for select to authenticated using (ikon_is_staff())','ikon_read_'||t,t); execute format('drop policy if exists %I on %I','ikon_staff_'||t,t); if t='customers' then execute format('create policy %I on %I for all to authenticated using (ikon_is_staff() or auth.uid()::text = id) with check (ikon_is_staff() or auth.uid()::text = id)','ikon_staff_'||t,t); else execute format('create policy %I on %I for all to authenticated using (ikon_is_staff()) with check (ikon_is_staff())','ikon_staff_'||t,t); end if; end loop; end $$;
alter table inventory_events replica identity full; alter table inventory replica identity full; alter table sales_orders replica identity full; alter table purchase_orders replica identity full;
do $$ declare t text; begin foreach t in array array['inventory','sales_orders','sales_lines','purchase_orders','purchase_lines','production_orders','returns','transfers','settings','customers','suppliers','items'] loop begin execute format('alter publication supabase_realtime add table %I',t); exception when duplicate_object then null; end; end loop; end $$;
insert into settings(key,value) values('ordering_cost',65),('annual_holding_rate',0.24),('tax_rate',0.075) on conflict(key) do nothing;

-- Safe defaults: self-service signups are customers. Promote the first manager in SQL Editor.
create or replace function ikon_new_profile() returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into profiles(id,full_name,role) values(new.id,coalesce(new.raw_user_meta_data->>'full_name',split_part(coalesce(new.email,''),'@',1)),'customer') on conflict(id) do nothing;
 return new;
end $$;
drop trigger if exists ikon_auth_profile on auth.users;
create trigger ikon_auth_profile after insert on auth.users for each row execute function ikon_new_profile();

drop policy if exists ikon_read_profiles on profiles;
create policy ikon_read_profiles on profiles for select to authenticated using (id=auth.uid() or ikon_is_staff());
drop policy if exists ikon_profile_self_insert on profiles;
create policy ikon_profile_self_insert on profiles for insert to authenticated with check (id=auth.uid() and role='customer');
drop policy if exists ikon_profile_self_update on profiles;
create policy ikon_profile_self_update on profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid() and role='customer');

-- Catalog and availability are readable to signed-in pickup customers.
drop policy if exists ikon_catalog_read on locations;
create policy ikon_catalog_read on locations for select to authenticated using (true);
drop policy if exists ikon_items_read on items;
create policy ikon_items_read on items for select to authenticated using (true);
drop policy if exists ikon_bom_read on bom;
create policy ikon_bom_read on bom for select to authenticated using (true);
drop policy if exists ikon_inventory_read on inventory;
create policy ikon_inventory_read on inventory for select to authenticated using (true);
drop policy if exists ikon_customers_read_self on customers;
create policy ikon_customers_read_self on customers for select to authenticated using (ikon_is_staff() or lower(email)=lower(auth.jwt()->>'email'));
drop policy if exists ikon_orders_read_owner on sales_orders;
create policy ikon_orders_read_owner on sales_orders for select to authenticated using (ikon_is_staff() or customer_id in (select id from customers where lower(email)=lower(auth.jwt()->>'email')));
drop policy if exists ikon_lines_read_owner on sales_lines;
create policy ikon_lines_read_owner on sales_lines for select to authenticated using (ikon_is_staff() or exists(select 1 from sales_orders o join customers c on c.id=o.customer_id where o.id=sales_lines.order_id and lower(c.email)=lower(auth.jwt()->>'email')));

-- POS commits the order and all stock movements in one transaction.
create or replace function ikon_commit_sale(p_order jsonb,p_lines jsonb) returns text language plpgsql security definer set search_path=public as $$
declare
 v_id text:=coalesce(p_order->>'id','SO-'||substr(gen_random_uuid()::text,1,8));
 v_loc text:=p_order->>'location_id'; v_customer text:=nullif(p_order->>'customer_id','');
 v_sub numeric:=0; v_cogs numeric:=0; v_discount numeric:=coalesce((p_order->>'discount')::numeric,0);
 v_tax_rate numeric; v_tax numeric; v_total numeric; v_line jsonb; v_item items%rowtype;
 v_qty int; v_stock int; v_comp record;
begin
 if auth.uid() is null or not ikon_is_staff() then raise exception 'Staff sign-in required'; end if;
 if not exists(select 1 from locations where id=v_loc) then raise exception 'Unknown sale location'; end if;
 for v_line in select value from jsonb_array_elements(p_lines) loop
  v_qty:=(v_line->>'qty')::int;
  if v_qty<1 then raise exception 'Quantity must be positive'; end if;
  select * into v_item from items where id=v_line->>'item_id';
  if not found then raise exception 'Unknown item'; end if;
  v_sub:=v_sub+v_item.price*v_qty; v_cogs:=v_cogs+v_item.cost*v_qty;
  select qty into v_stock from inventory where item_id=v_item.id and location_id=v_loc for update;
  if coalesce(v_stock,0)<v_qty then raise exception 'Insufficient inventory for %',v_item.name; end if;
  update inventory set qty=qty-v_qty where item_id=v_item.id and location_id=v_loc;
  insert into inventory_events(item_id,location_id,qty_delta,reason,ref_type,ref_id,actor) values(v_item.id,v_loc,-v_qty,'POS sale','sales_order',v_id,auth.uid());
  if v_item.is_parent then
   for v_comp in select b.component_id,(b.qty_per*v_qty)::int as qty from bom b where b.parent_id=v_item.id loop
    select qty into v_stock from inventory where item_id=v_comp.component_id and location_id=v_loc for update;
    if coalesce(v_stock,0)<v_comp.qty then raise exception 'Insufficient assembly component stock'; end if;
    update inventory set qty=qty-v_comp.qty where item_id=v_comp.component_id and location_id=v_loc;
    insert into inventory_events(item_id,location_id,qty_delta,reason,ref_type,ref_id,actor) values(v_comp.component_id,v_loc,-v_comp.qty,'BOM issue on sale','sales_order',v_id,auth.uid());
   end loop;
  end if;
 end loop;
 v_discount:=least(v_sub,greatest(0,v_discount));
 select coalesce(value,.075) into v_tax_rate from settings where key='tax_rate';
 v_tax:=round((v_sub-v_discount)*coalesce(v_tax_rate,.075),2); v_total:=v_sub-v_discount+v_tax;
 insert into sales_orders(id,customer_id,location_id,status,channel,subtotal,tax,discount,total,cogs) values(v_id,v_customer,v_loc,'Closed','POS',v_sub,v_tax,v_discount,v_total,v_cogs);
 for v_line in select value from jsonb_array_elements(p_lines) loop
  select * into v_item from items where id=v_line->>'item_id';
  insert into sales_lines(order_id,item_id,qty,unit_price,unit_cost) values(v_id,v_item.id,(v_line->>'qty')::int,v_item.price,v_item.cost);
 end loop;
 insert into audit_log(actor,action,entity,entity_id) values(auth.uid(),'POS sale','sales_order',v_id);
 return v_id;
end $$;

-- Customers reserve pickup stock; fulfillment is recorded by staff later.
create or replace function ikon_place_pickup(p_item_id text,p_qty int,p_location_id text) returns text language plpgsql security definer set search_path=public as $$
declare v_item items%rowtype; v_id text:='PU-'||substr(gen_random_uuid()::text,1,8); v_customer text; v_tax numeric; v_stock int;
begin
 if auth.uid() is null then raise exception 'Customer sign-in required'; end if;
 if p_qty<1 then raise exception 'Quantity must be positive'; end if;
 select * into v_item from items where id=p_item_id and price>0;
 if not found then raise exception 'Item is unavailable'; end if;
 if not exists(select 1 from locations where id=p_location_id) then raise exception 'Unknown pickup location'; end if;
 select qty into v_stock from inventory where item_id=p_item_id and location_id=p_location_id for update;
 if coalesce(v_stock,0)<p_qty then raise exception 'Insufficient pickup stock; ask staff to place a backorder'; end if;
 select id into v_customer from customers where lower(email)=lower(auth.jwt()->>'email') limit 1;
 if v_customer is null then
  v_customer:=auth.uid()::text;
  insert into customers(id,name,email) values(v_customer,coalesce(auth.jwt()->>'email','IKONic customer'),auth.jwt()->>'email') on conflict(id) do nothing;
 end if;
 select coalesce(value,.075) into v_tax from settings where key='tax_rate';
 insert into sales_orders(id,customer_id,location_id,status,channel,subtotal,tax,total,cogs) values(v_id,v_customer,p_location_id,'Order Placed','Pickup',v_item.price*p_qty,round(v_item.price*p_qty*coalesce(v_tax,.075),2),round(v_item.price*p_qty*(1+coalesce(v_tax,.075)),2),v_item.cost*p_qty);
 insert into sales_lines(order_id,item_id,qty,unit_price,unit_cost) values(v_id,v_item.id,p_qty,v_item.price,v_item.cost);
 return v_id;
end $$;
