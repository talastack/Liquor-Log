-- Patch 0010, 16 September 2026: fill level by weight, blind tastings.
-- Re-runnable.

alter table bottles  add column if not exists tare_grams double precision;
alter table tastings add column if not exists blind      boolean not null default false;
