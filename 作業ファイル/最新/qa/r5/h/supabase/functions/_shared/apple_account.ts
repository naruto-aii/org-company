// Sign in with Apple refresh-token exchange and account-deletion revoke.
// Key material comes from Edge Function secrets. Nothing in this file is a
// credential. Do not log authorization codes, refresh tokens, client secrets,
// or the private key.

export const appleAuthTokenUrl = "https://appleid.apple.com/auth/token";
export const appleAuthRevokeUrl = "https://appleid.apple.com/auth/revoke";

export const appleSecretEnvNames = [
  "APPLE_TEAM_ID",
  "APPLE_KEY_ID",
  "APPLE_PRIVATE_KEY",
  "APPLE_CLIENT_ID",
] as const;

const clientSecretLifetimeSeconds = 150 * 24 * 60 * 60;
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type AppleSecrets = {
  teamId: string;
  keyId: string;
  privateKeyPem: string;
  clientId: string;
};

export type EnvMap = {
  SUPABASE_URL?: string;
  SUPABASE_ANON_KEY?: string;
  SUPABASE_SERVICE_ROLE_KEY?: string;
  APPLE_TEAM_ID?: string;
  APPLE_KEY_ID?: string;
  APPLE_PRIVATE_KEY?: string;
  APPLE_CLIENT_ID?: string;
};

export type FetchLike = (
  input: string,
  init?: RequestInit,
) => Promise<Response>;

export type LogFn = (message: string) => void;

export function isUuid(value: string): boolean {
  return uuidPattern.test(value);
}

export function normalizePrivateKey(raw: string): string {
  let value = raw.trim();
  if (
    (value.startsWith('"') && value.endsWith('"')) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    value = value.slice(1, -1);
  }
  return value.replaceAll("\\n", "\n").trim();
}

export function appleSecretsFromEnv(env: EnvMap): AppleSecrets | null {
  const teamId = env.APPLE_TEAM_ID?.trim() ?? "";
  const keyId = env.APPLE_KEY_ID?.trim() ?? "";
  const clientId = env.APPLE_CLIENT_ID?.trim() ?? "";
  const privateKeyPem = normalizePrivateKey(env.APPLE_PRIVATE_KEY ?? "");
  if (!teamId || !keyId || !clientId || !privateKeyPem) {
    return null;
  }
  return { teamId, keyId, privateKeyPem, clientId };
}

export function logWithoutSecrets(
  log: LogFn,
  message: string,
  secrets: Array<string | null | undefined>,
): void {
  for (const secret of secrets) {
    if (secret && secret.length >= 6 && message.includes(secret)) {
      log("apple log suppressed");
      return;
    }
  }
  log(message);
}

function bytesToBase64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll(
    "=",
    "",
  );
}

function textToBase64Url(value: string): string {
  return bytesToBase64Url(new TextEncoder().encode(value));
}

export function decodeBase64Url(input: string): Uint8Array {
  const padded = input.replaceAll("-", "+").replaceAll("_", "/") +
    "=".repeat((4 - (input.length % 4)) % 4);
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function pemToPkcs8(pem: string): Uint8Array {
  const body = pem
    .replaceAll("-----BEGIN PRIVATE KEY-----", "")
    .replaceAll("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  if (!body) {
    throw new Error("apple private key is empty");
  }
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

export async function appleClientSecret(
  secrets: AppleSecrets,
  nowSeconds: number,
): Promise<string> {
  const pkcs8 = pemToPkcs8(secrets.privateKeyPem);
  const keyBytes = new Uint8Array(pkcs8.byteLength);
  keyBytes.set(pkcs8);
  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyBytes,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const header = textToBase64Url(JSON.stringify({
    alg: "ES256",
    kid: secrets.keyId,
  }));
  const payload = textToBase64Url(JSON.stringify({
    iss: secrets.teamId,
    iat: nowSeconds,
    exp: nowSeconds + clientSecretLifetimeSeconds,
    aud: "https://appleid.apple.com",
    sub: secrets.clientId,
  }));
  const signingInput = `${header}.${payload}`;
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${bytesToBase64Url(new Uint8Array(signature))}`;
}

export function appleErrorCode(json: unknown): string {
  if (!json || typeof json !== "object") {
    return "";
  }
  const code = (json as { error?: unknown }).error;
  if (typeof code !== "string" || !/^[a-z0-9_]{1,64}$/i.test(code)) {
    return "";
  }
  return code;
}

export function refreshTokenFromAppleJson(json: unknown): string | null {
  if (!json || typeof json !== "object") {
    return null;
  }
  const token = (json as { refresh_token?: unknown }).refresh_token;
  if (typeof token !== "string" || token.length === 0 || token.length > 4096) {
    return null;
  }
  return token;
}

export function refreshTokenFromRpcText(text: string): string | null {
  const trimmed = text.trim();
  if (!trimmed || trimmed === "null") {
    return null;
  }
  try {
    const parsed = JSON.parse(trimmed);
    if (typeof parsed !== "string" || parsed.length === 0 || parsed.length > 4096) {
      return null;
    }
    return parsed;
  } catch {
    return null;
  }
}

function bearer(value: string): string {
  return /^Bearer\s+/i.test(value) ? value : `Bearer ${value}`;
}

export function rpcRequest(args: {
  supabaseUrl: string;
  apiKey: string;
  authorization: string;
  fn: string;
  body: Record<string, string>;
  minimal: boolean;
}): { url: string; init: RequestInit } {
  const headers: Record<string, string> = {
    apikey: args.apiKey,
    Authorization: bearer(args.authorization),
    "Content-Type": "application/json",
  };
  if (args.minimal) {
    headers.Prefer = "return=minimal";
  }
  return {
    url: `${args.supabaseUrl.replace(/\/$/, "")}/rest/v1/rpc/${args.fn}`,
    init: {
      method: "POST",
      headers,
      body: JSON.stringify(args.body),
    },
  };
}

export function jsonResponse(
  body: { ok?: boolean; stored?: boolean; apple_revoke_failed?: boolean },
  status: number,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// Web preview origin. The path is not part of the browser Origin header.
export const publishedWebOrigin = "https://naruto-aii.github.io";

const corsAllowHeaders = "authorization, x-client-info, apikey, content-type";

// Local origins stay off unless this is set. Production must not set it.
// A missing env permission is the same as unset: localhost stays closed.
function localhostOriginsAllowed(): boolean {
  try {
    return Deno.env.get("ALLOW_LOCALHOST_ORIGIN") === "true";
  } catch {
    return false;
  }
}

export function isAllowedWebOrigin(origin: string | null): boolean {
  if (!origin) {
    return false;
  }
  if (origin === publishedWebOrigin) {
    return true;
  }
  if (!localhostOriginsAllowed()) {
    return false;
  }
  let url: URL;
  try {
    url = new URL(origin);
  } catch {
    return false;
  }
  if (url.protocol !== "http:" || url.username !== "" || url.password !== "") {
    return false;
  }
  return url.hostname === "localhost" || url.hostname === "127.0.0.1";
}

export function withWebCors(req: Request, response: Response): Response {
  const origin = req.headers.get("Origin");
  if (!origin || !isAllowedWebOrigin(origin)) {
    return response;
  }
  const headers = new Headers(response.headers);
  headers.set("Access-Control-Allow-Origin", origin);
  headers.set("Vary", "Origin");
  headers.set("Access-Control-Allow-Headers", corsAllowHeaders);
  headers.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  return new Response(response.body, { status: response.status, headers });
}

export function webPreflight(req: Request): Response {
  if (!isAllowedWebOrigin(req.headers.get("Origin"))) {
    return new Response(null, { status: 403 });
  }
  const response = withWebCors(req, new Response(null, { status: 204 }));
  const headers = new Headers(response.headers);
  headers.set("Access-Control-Max-Age", "86400");
  return new Response(null, { status: 204, headers });
}

async function appleFormRequest(args: {
  url: string;
  fields: Record<string, string>;
  fetchImpl: FetchLike;
}): Promise<{ ok: boolean; status: number; json: unknown }> {
  try {
    const response = await args.fetchImpl(args.url, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams(args.fields).toString(),
      signal: AbortSignal.timeout(10_000),
    });
    const text = await response.text();
    let json: unknown = null;
    if (text) {
      try {
        json = JSON.parse(text);
      } catch {
        json = null;
      }
    }
    return { ok: response.ok, status: response.status, json };
  } catch {
    return { ok: false, status: 0, json: null };
  }
}

export async function exchangeAuthorizationCode(args: {
  authorizationCode: string;
  secrets: AppleSecrets;
  fetchImpl: FetchLike;
  nowSeconds?: number;
}): Promise<{ refreshToken: string | null; status: number; errorCode: string }> {
  const now = args.nowSeconds ?? Math.floor(Date.now() / 1000);
  let clientSecret: string;
  try {
    clientSecret = await appleClientSecret(args.secrets, now);
  } catch {
    return { refreshToken: null, status: 0, errorCode: "client_secret" };
  }
  const result = await appleFormRequest({
    url: appleAuthTokenUrl,
    fetchImpl: args.fetchImpl,
    fields: {
      grant_type: "authorization_code",
      code: args.authorizationCode,
      client_id: args.secrets.clientId,
      client_secret: clientSecret,
    },
  });
  return {
    refreshToken: result.ok ? refreshTokenFromAppleJson(result.json) : null,
    status: result.status,
    errorCode: result.ok ? "" : appleErrorCode(result.json),
  };
}

export async function revokeRefreshToken(args: {
  refreshToken: string;
  secrets: AppleSecrets;
  fetchImpl: FetchLike;
  nowSeconds?: number;
}): Promise<{ ok: boolean; status: number; errorCode: string }> {
  const now = args.nowSeconds ?? Math.floor(Date.now() / 1000);
  let clientSecret: string;
  try {
    clientSecret = await appleClientSecret(args.secrets, now);
  } catch {
    return { ok: false, status: 0, errorCode: "client_secret" };
  }
  const result = await appleFormRequest({
    url: appleAuthRevokeUrl,
    fetchImpl: args.fetchImpl,
    fields: {
      client_id: args.secrets.clientId,
      client_secret: clientSecret,
      token: args.refreshToken,
      token_type_hint: "refresh_token",
    },
  });
  return {
    ok: result.ok,
    status: result.status,
    errorCode: result.ok ? "" : appleErrorCode(result.json),
  };
}

export async function resolveSupabaseUserId(args: {
  supabaseUrl: string;
  anonKey: string;
  authorization: string | null;
  fetchImpl: FetchLike;
}): Promise<string | null> {
  const authorization = args.authorization?.trim() ?? "";
  if (!/^Bearer\s+\S+$/i.test(authorization)) {
    return null;
  }
  if (!args.supabaseUrl || !args.anonKey) {
    return null;
  }
  const response = await args.fetchImpl(
    `${args.supabaseUrl.replace(/\/$/, "")}/auth/v1/user`,
    {
      headers: {
        apikey: args.anonKey,
        Authorization: authorization,
      },
    },
  );
  if (!response.ok) {
    return null;
  }
  try {
    const body = await response.json();
    const id = body && typeof body === "object"
      ? (body as { id?: unknown }).id
      : null;
    return typeof id === "string" && isUuid(id) ? id : null;
  } catch {
    return null;
  }
}

export type ExchangeResult = {
  refreshToken: string | null;
  status: number;
  errorCode: string;
};

export type StoreDeps = {
  resolveUserId(authorization: string | null): Promise<string | null>;
  exchange(authorizationCode: string): Promise<ExchangeResult>;
  storeToken(userId: string, refreshToken: string): Promise<void>;
  log: LogFn;
};

export type DeleteDeps = {
  resolveUserId(authorization: string | null): Promise<string | null>;
  readToken(userId: string): Promise<string | null>;
  // true when Auth has an Apple identity, false when the lookup succeeded
  // and there is none, null when the lookup failed.
  appleLinked(userId: string): Promise<boolean | null>;
  revoke(refreshToken: string): Promise<{ ok: boolean; status: number; errorCode: string }>;
  deleteAccount(userId: string): Promise<void>;
  deleteStoredToken(userId: string): Promise<void>;
  log: LogFn;
};

async function authorizationCodeFromRequest(req: Request): Promise<string | null> {
  try {
    const body = await req.json();
    const code = body && typeof body === "object"
      ? (body as { authorization_code?: unknown }).authorization_code
      : null;
    if (typeof code !== "string") {
      return null;
    }
    const trimmed = code.trim();
    if (!trimmed || trimmed.length > 2048) {
      return null;
    }
    return trimmed;
  } catch {
    return null;
  }
}

export async function handleStoreAppleRefreshToken(
  req: Request,
  deps: StoreDeps,
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return webPreflight(req);
  }
  return withWebCors(req, await storeAppleRefreshToken(req, deps));
}

async function storeAppleRefreshToken(
  req: Request,
  deps: StoreDeps,
): Promise<Response> {
  if (req.method !== "POST") {
    return jsonResponse({ stored: false }, 405);
  }
  let userId: string | null;
  try {
    userId = await deps.resolveUserId(req.headers.get("Authorization"));
  } catch {
    deps.log("apple refresh token user lookup failed");
    return jsonResponse({ stored: false }, 200);
  }
  if (!userId) {
    return jsonResponse({ stored: false }, 401);
  }

  const code = await authorizationCodeFromRequest(req);
  if (!code) {
    deps.log("apple authorization code missing");
    return jsonResponse({ stored: false }, 200);
  }

  let exchanged: ExchangeResult;
  try {
    exchanged = await deps.exchange(code);
  } catch {
    deps.log("apple token exchange failed");
    return jsonResponse({ stored: false }, 200);
  }
  if (!exchanged.refreshToken) {
    const codePart = exchanged.errorCode ? ` code=${exchanged.errorCode}` : "";
    logWithoutSecrets(
      deps.log,
      `apple token exchange failed status=${exchanged.status}${codePart}`,
      [code, exchanged.refreshToken],
    );
    return jsonResponse({ stored: false }, 200);
  }
  try {
    await deps.storeToken(userId, exchanged.refreshToken);
  } catch {
    deps.log("apple refresh token store failed");
    return jsonResponse({ stored: false }, 200);
  }
  return jsonResponse({ stored: true }, 200);
}

export function appleIdentityInAdminUser(text: string): boolean | null {
  try {
    const parsed = JSON.parse(text) as {
      identities?: Array<{ provider?: string }>;
      app_metadata?: { provider?: string; providers?: string[] };
    };
    const names = [
      ...(parsed.identities ?? []).map((row) => row.provider),
      parsed.app_metadata?.provider,
      ...(parsed.app_metadata?.providers ?? []),
    ];
    return names.some((name) => name?.toLowerCase() === "apple");
  } catch {
    return null;
  }
}

// Delete the account first. Apple is called only after that succeeds, and
// only when a refresh token was already read into memory. A failed deletion
// leaves the Apple link untouched.
export async function deleteThenRevokeAccount(args: {
  userId: string;
  deps: DeleteDeps;
}): Promise<"deleted" | "deleted_revoke_failed" | "delete_failed"> {
  let token: string | null = null;
  try {
    token = await args.deps.readToken(args.userId);
  } catch {
    args.deps.log("apple refresh token read failed");
  }

  let appleLinked: boolean | null = false;
  if (!token) {
    try {
      appleLinked = await args.deps.appleLinked(args.userId);
    } catch {
      appleLinked = null;
    }
    if (appleLinked === null) {
      args.deps.log("apple identity lookup failed");
    }
  }

  try {
    await args.deps.deleteAccount(args.userId);
  } catch {
    args.deps.log("delete_own_account failed");
    return "delete_failed";
  }

  let revokeFailed = false;
  if (token) {
    try {
      const revoked = await args.deps.revoke(token);
      if (!revoked.ok) {
        revokeFailed = true;
        const codePart = revoked.errorCode ? ` code=${revoked.errorCode}` : "";
        logWithoutSecrets(
          args.deps.log,
          `apple token revoke failed status=${revoked.status}${codePart}`,
          [token],
        );
      }
    } catch {
      revokeFailed = true;
      args.deps.log("apple token revoke failed");
    }
  } else if (appleLinked) {
    revokeFailed = true;
    args.deps.log("apple token missing for linked account");
  } else {
    args.deps.log("apple token revoke skipped");
  }

  try {
    await args.deps.deleteStoredToken(args.userId);
  } catch {
    args.deps.log("apple refresh token delete failed");
  }
  return revokeFailed ? "deleted_revoke_failed" : "deleted";
}

export async function handleDeleteAccount(
  req: Request,
  deps: DeleteDeps,
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return webPreflight(req);
  }
  return withWebCors(req, await deleteAccountResponse(req, deps));
}

async function deleteAccountResponse(
  req: Request,
  deps: DeleteDeps,
): Promise<Response> {
  if (req.method !== "POST") {
    return jsonResponse({ ok: false }, 405);
  }
  const authorization = req.headers.get("Authorization");
  let userId: string | null;
  try {
    userId = await deps.resolveUserId(authorization);
  } catch {
    deps.log("delete account user lookup failed");
    return jsonResponse({ ok: false }, 500);
  }
  if (!userId || !authorization) {
    return jsonResponse({ ok: false }, 401);
  }
  const result = await deleteThenRevokeAccount({
    userId,
    deps,
  });
  if (result === "deleted" || result === "deleted_revoke_failed") {
    return jsonResponse(
      result === "deleted_revoke_failed"
        ? { ok: true, apple_revoke_failed: true }
        : { ok: true },
      200,
    );
  }
  return jsonResponse({ ok: false }, 500);
}

function platform(env: EnvMap): {
  supabaseUrl: string;
  anonKey: string;
  serviceRoleKey: string;
} {
  return {
    supabaseUrl: env.SUPABASE_URL?.trim() ?? "",
    anonKey: env.SUPABASE_ANON_KEY?.trim() ?? "",
    serviceRoleKey: env.SUPABASE_SERVICE_ROLE_KEY?.trim() ?? "",
  };
}

async function rpcOk(
  fetchImpl: FetchLike,
  call: { url: string; init: RequestInit },
): Promise<Response> {
  const response = await fetchImpl(call.url, call.init);
  if (!response.ok) {
    throw new Error("rpc failed");
  }
  return response;
}

export function storeDepsFrom(env: EnvMap, fetchImpl: FetchLike): StoreDeps {
  const { supabaseUrl, anonKey, serviceRoleKey } = platform(env);
  return {
    log: (message) => console.error(message),
    resolveUserId: (authorization) =>
      resolveSupabaseUserId({
        supabaseUrl,
        anonKey,
        authorization,
        fetchImpl,
      }),
    exchange: async (authorizationCode) => {
      const secrets = appleSecretsFromEnv(env);
      if (!secrets) {
        return { refreshToken: null, status: 0, errorCode: "secrets_missing" };
      }
      return exchangeAuthorizationCode({
        authorizationCode,
        secrets,
        fetchImpl,
      });
    },
    storeToken: async (userId, refreshToken) => {
      if (!supabaseUrl || !serviceRoleKey || !isUuid(userId)) {
        throw new Error("store unconfigured");
      }
      await rpcOk(
        fetchImpl,
        rpcRequest({
          supabaseUrl,
          apiKey: serviceRoleKey,
          authorization: serviceRoleKey,
          fn: "store_apple_refresh_token",
          body: { p_user_id: userId, p_refresh_token: refreshToken },
          minimal: true,
        }),
      );
    },
  };
}

export function deleteDepsFrom(env: EnvMap, fetchImpl: FetchLike): DeleteDeps {
  const { supabaseUrl, anonKey, serviceRoleKey } = platform(env);
  return {
    log: (message) => console.error(message),
    resolveUserId: (authorization) =>
      resolveSupabaseUserId({
        supabaseUrl,
        anonKey,
        authorization,
        fetchImpl,
      }),
    readToken: async (userId) => {
      if (!supabaseUrl || !serviceRoleKey || !isUuid(userId)) {
        throw new Error("read unconfigured");
      }
      const response = await rpcOk(
        fetchImpl,
        rpcRequest({
          supabaseUrl,
          apiKey: serviceRoleKey,
          authorization: serviceRoleKey,
          fn: "read_apple_refresh_token",
          body: { p_user_id: userId },
          minimal: false,
        }),
      );
      return refreshTokenFromRpcText(await response.text());
    },
    appleLinked: async (userId) => {
      if (!supabaseUrl || !serviceRoleKey || !isUuid(userId)) {
        return null;
      }
      const response = await fetchImpl(
        `${supabaseUrl.replace(/\/$/, "")}/auth/v1/admin/users/${userId}`,
        {
          headers: {
            apikey: serviceRoleKey,
            Authorization: bearer(serviceRoleKey),
          },
        },
      );
      if (!response.ok) {
        return null;
      }
      return appleIdentityInAdminUser(await response.text());
    },
    revoke: async (refreshToken) => {
      const secrets = appleSecretsFromEnv(env);
      if (!secrets) {
        return { ok: false, status: 0, errorCode: "secrets_missing" };
      }
      return revokeRefreshToken({ refreshToken, secrets, fetchImpl });
    },
    deleteAccount: async (userId) => {
      if (!supabaseUrl || !serviceRoleKey || !isUuid(userId)) {
        throw new Error("delete unconfigured");
      }
      await rpcOk(
        fetchImpl,
        rpcRequest({
          supabaseUrl,
          apiKey: serviceRoleKey,
          authorization: serviceRoleKey,
          fn: "delete_own_account",
          body: { p_user_id: userId },
          minimal: true,
        }),
      );
    },
    deleteStoredToken: async (userId) => {
      if (!supabaseUrl || !serviceRoleKey || !isUuid(userId)) {
        throw new Error("delete token unconfigured");
      }
      await rpcOk(
        fetchImpl,
        rpcRequest({
          supabaseUrl,
          apiKey: serviceRoleKey,
          authorization: serviceRoleKey,
          fn: "delete_apple_refresh_token",
          body: { p_user_id: userId },
          minimal: true,
        }),
      );
    },
  };
}

export function liveStoreDeps(): StoreDeps {
  return storeDepsFrom(Deno.env.toObject(), fetch);
}

export function liveDeleteDeps(): DeleteDeps {
  return deleteDepsFrom(Deno.env.toObject(), fetch);
}
