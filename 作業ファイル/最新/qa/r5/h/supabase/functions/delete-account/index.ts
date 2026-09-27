import {
  handleDeleteAccount,
  jsonResponse,
  liveDeleteDeps,
  withWebCors,
} from "../_shared/apple_account.ts";

Deno.serve(async (req) => {
  try {
    return await handleDeleteAccount(req, liveDeleteDeps());
  } catch {
    console.error("delete-account failed");
    return withWebCors(req, jsonResponse({ ok: false }, 500));
  }
});
