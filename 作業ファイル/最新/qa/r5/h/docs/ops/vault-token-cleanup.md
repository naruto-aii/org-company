# Vault に残った Apple 更新用トークンの手動削除

アカウント削除が成功したあと、Edge Function `delete-account` は `public.delete_apple_refresh_token` で Vault の行を消します。この削除に失敗すると、削除済みユーザーの更新用トークンが残ります。定期削除はありません。

このファイルは手順です。マイグレーションではありません。この変更では本番に実行しません。

消すのは Vault の行だけです。Apple への連携解除はやり直しません。解除に失敗した利用者には、設定 > Apple ID > サインインとセキュリティ から自分で解除する案内を出しています。行を消したあとは、サーバーから同じトークンで解除できません。

## どこに残るか

`public.store_apple_refresh_token` は `vault.secrets` に、名前 `apple_refresh_token:` のあとにユーザー ID を付けて保存します。中身は `vault.decrypted_secrets.decrypted_secret` で復号できます。確認の SELECT では、`secret` も `decrypted_secret` も選ばないでください。

Supabase の SQL Editor（postgres）で実行します。`vault` は Data API に出ていません。

## 削除済みとみなす記録

`delete_own_account` は `auth.users` の行を消しません。成功した削除は次の状態です。

- `public.users.deleted_at` が入っている（`20260920120000` で列を追加し、削除関数がセットする）
- `auth.users.email` が `deleted+<ユーザー ID>@invalid.local`
- ダッシュボードから `auth.users` の行そのものを消した場合は、`public.users` も外部キーで消え、トークン名に対応するユーザーがどちらにもいない

ログイン中のユーザー（`deleted_at` が空で、メールが上の形ではない）は対象外です。

## 1. 読み取り専用の確認

先にこれだけ実行し、出た行がすべて削除済みであることを見ます。0 行なら以降は不要です。

```sql
select
  s.id,
  s.name,
  s.created_at,
  s.updated_at,
  u.deleted_at as public_deleted_at,
  au.email as auth_email
from vault.secrets as s
left join public.users as u
  on s.name = 'apple_refresh_token:' || u.id::text
left join auth.users as au
  on s.name = 'apple_refresh_token:' || au.id::text
where pg_catalog.starts_with(s.name, 'apple_refresh_token:')
  and (
    u.deleted_at is not null
    or au.email = 'deleted+' || au.id::text || '@invalid.local'
    or au.id is null
  )
order by s.created_at;
```

`created_at` が無いというエラーになった場合は、その2列を外して `id` と `name` と `public_deleted_at` と `auth_email` だけを選んでください。本番の `supabase_vault` には `created_at` と `updated_at` があります。

## 2. 削除

確認結果にログイン中のユーザーが無いときだけ、同じ条件で削除します。トランザクションのまま、削除後にもう一度 1 の SELECT を実行し、0 行であることを見てから commit します。想定と違う行があれば rollback します。

```sql
begin;

delete from vault.secrets as s
where s.id in (
  select s2.id
  from vault.secrets as s2
  left join public.users as u
    on s2.name = 'apple_refresh_token:' || u.id::text
  left join auth.users as au
    on s2.name = 'apple_refresh_token:' || au.id::text
  where pg_catalog.starts_with(s2.name, 'apple_refresh_token:')
    and (
      u.deleted_at is not null
      or au.email = 'deleted+' || au.id::text || '@invalid.local'
      or au.id is null
    )
);

-- 1 の SELECT を再実行し、0 行なら commit、そうでなければ rollback。
```
