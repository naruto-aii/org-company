#!/bin/bash
# 再現手順（箱内のローカル PG17 のみ。本番に触れない）
export PATH=/usr/lib/postgresql/17/bin:$PATH
D=/tmp/pgqa; [ -d $D ] || initdb -D $D -E UTF8 --locale=C.UTF-8 -U postgres >/dev/null
pg_ctl -D $D -o "-p 55432 -k /tmp" -l /tmp/pgqa.log start
psql -h /tmp -p 55432 -U postgres -c "select pg_catalog.coalesce(null::text,'x')"          # ERROR
psql -h /tmp -p 55432 -U postgres -c "select pg_catalog.greatest(1,2)"                    # ERROR
psql -h /tmp -p 55432 -U postgres -c "select 'a'::text where pg_catalog.current_user = 'x'" # ERROR
psql -h /tmp -p 55432 -U postgres -c "select 'NFKC'::pg_catalog.normalization_form"      # ERROR
