import {
  appleClientSecret,
  appleSecretsFromEnv,
  deleteDepsFrom,
  handleDeleteAccount,
  handleStoreAppleRefreshToken,
  logWithoutSecrets,
  appleIdentityInAdminUser,
  deleteThenRevokeAccount,
  publishedWebOrigin,
  storeDepsFrom,
  type AppleSecrets,
  type DeleteDeps,
  type FetchLike,
} from "./apple_account.ts";

const userId = "11111111-1111-4111-8111-111111111111";
const refreshToken = "refresh-token-value";
const authorizationCode = "auth-code-value";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) {
    throw new Error(message);
  }
}

function b64url(value: string): string {
  return btoa(value).replaceAll("+", "-").replaceAll("/", "_").replaceAll(
    "=",
    "",
  );
}

function userAuthorization(): string {
  const header = b64url(JSON.stringify({ alg: "ES256", typ: "JWT" }));
  const payload = b64url(JSON.stringify({ sub: userId }));
  return `Bearer ${header}.${payload}.sig`;
}

function derToPem(der: ArrayBuffer): string {
  const bytes = new Uint8Array(der);
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  const lines = btoa(binary).match(/.{1,64}/g) ?? [];
  return `-----BEGIN PRIVATE KEY-----\n${lines.join("\n")}\n-----END PRIVATE KEY-----\n`;
}

const keyPair = await crypto.subtle.generateKey(
  { name: "ECDSA", namedCurve: "P-256" },
  true,
  ["sign", "verify"],
);
const pem = derToPem(await crypto.subtle.exportKey("pkcs8", keyPair.privateKey));

function sampleSecrets(privateKeyPem = pem): AppleSecrets {
  return {
    teamId: "TEAMID1234",
    keyId: "KEYID12345",
    privateKeyPem,
    clientId: "com.example.app",
  };
}

function platformEnv(extra: Record<string, string> = {}) {
  return {
    SUPABASE_URL: "https://example.supabase.co",
    SUPABASE_ANON_KEY: "anon-key",
    SUPABASE_SERVICE_ROLE_KEY: "service-key",
    APPLE_TEAM_ID: "TEAMID1234",
    APPLE_KEY_ID: "KEYID12345",
    APPLE_PRIVATE_KEY: pem,
    APPLE_CLIENT_ID: "com.example.app",
    ...extra,
  };
}

type Call = {
  url: string;
  authorization: string;
  apikey: string;
  body: string;
};

function header(init: RequestInit | undefined, name: string): string {
  const headers = init?.headers;
  if (!headers || headers instanceof Headers || Array.isArray(headers)) {
    return "";
  }
  const record = headers as Record<string, string>;
  return record[name] ?? "";
}

Deno.test("client secret is an ES256 JWT signed by the p8 key", async () => {
  const now = 1_700_000_000;
  const jwt = await appleClientSecret(sampleSecrets(), now);
  assert(!jwt.includes("PRIVATE"), "jwt contains key material");
  const parts = jwt.split(".");
  assert(parts.length === 3, "jwt parts");
  const header = JSON.parse(new TextDecoder().decode(base64UrlBytes(parts[0])));
  const payload = JSON.parse(new TextDecoder().decode(base64UrlBytes(parts[1])));
  assert(header.alg === "ES256", "alg");
  assert(header.kid === "KEYID12345", "kid");
  assert(payload.iss === "TEAMID1234", "iss");
  assert(payload.sub === "com.example.app", "sub");
  assert(payload.aud === "https://appleid.apple.com", "aud");
  assert(payload.iat === now, "iat");
  assert(payload.exp === now + 150 * 24 * 60 * 60, "exp");
  const verified = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    keyPair.publicKey,
    toArrayBuffer(base64UrlBytes(parts[2])),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
  assert(verified, "signature");
});

Deno.test("escaped newlines in the private key still sign", async () => {
  const escaped = pem.replaceAll("\n", "\\n");
  const fromEnv = appleSecretsFromEnv({ APPLE_TEAM_ID: "TEAMID1234", APPLE_KEY_ID: "KEYID12345", APPLE_PRIVATE_KEY: escaped, APPLE_CLIENT_ID: "com.example.app" });
  assert(fromEnv, "secrets");
  const jwt = await appleClientSecret(fromEnv, 1_700_000_000);
  const parts = jwt.split(".");
  const verified = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    keyPair.publicKey,
    toArrayBuffer(base64UrlBytes(parts[2])),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
  assert(verified, "escaped pem signature");
});

Deno.test("missing apple secret is not replaced with a client id", () => {
  const secrets = appleSecretsFromEnv({
    APPLE_TEAM_ID: "TEAMID1234",
    APPLE_KEY_ID: "KEYID12345",
    APPLE_PRIVATE_KEY: pem,
  });
  assert(secrets === null, "client id is required");
});

Deno.test("logs drop messages that include a token", () => {
  const logs: string[] = [];
  logWithoutSecrets((message) => logs.push(message), `status=${refreshToken}`, [
    refreshToken,
  ]);
  logWithoutSecrets((message) => logs.push(message), "apple token revoke failed status=400", [
    refreshToken,
  ]);
  assert(logs[0] === "apple log suppressed", "suppressed");
  assert(logs[1] === "apple token revoke failed status=400", "kept");
  assert(!logs.join("\n").includes(refreshToken), "token absent");
});

Deno.test("store sends the authorization code and hides exchange failure", async () => {
  const calls: Call[] = [];
  const fetchImpl = fakeFetch(calls, {
    appleStatus: 400,
    appleBody: { error: "invalid_grant" },
  });
  const logs: string[] = [];
  const deps = storeDepsFrom(platformEnv(), fetchImpl);
  deps.log = (message) => logs.push(message);
  const response = await handleStoreAppleRefreshToken(jsonRequest({
    authorization_code: authorizationCode,
  }), deps);
  assert(response.status === 200, "status");
  const text = await response.text();
  assert(text === '{"stored":false}', text);
  assert(!text.includes(authorizationCode), "code echoed");
  assert(!text.includes(refreshToken), "token echoed");
  assert(calls.some((call) => call.url === "https://appleid.apple.com/auth/token"), "exchanged");
  assert(!calls.some((call) => call.url.includes("store_apple_refresh_token")), "not stored");
  const apple = calls.find((call) => call.url.includes("/auth/token"));
  assert(apple?.body.includes("grant_type=authorization_code"), "grant");
  assert(apple?.body.includes(`code=${authorizationCode}`), "code sent");
  assert(apple?.body.includes("client_id=com.example.app"), "client id");
  assert(!logs.join("\n").includes(authorizationCode), "code logged");
  assert(logs.some((line) => line.includes("status=400")), "status logged");
});

Deno.test("store keeps the refresh token on the server", async () => {
  const calls: Call[] = [];
  const deps = storeDepsFrom(platformEnv(), fakeFetch(calls, {
    appleStatus: 200,
    appleBody: { refresh_token: refreshToken, access_token: "access-token-value" },
  }));
  const response = await handleStoreAppleRefreshToken(jsonRequest({
    authorization_code: authorizationCode,
  }), deps);
  const text = await response.text();
  assert(response.status === 200, "status");
  assert(text === '{"stored":true}', text);
  assert(!text.includes(refreshToken), "token in response");
  assert(!text.includes("access-token-value"), "access token in response");
  const stored = calls.find((call) => call.url.endsWith("/rpc/store_apple_refresh_token"));
  assert(stored, "store rpc");
  assert(stored.authorization === "Bearer service-key", "service role");
  assert(stored.apikey === "service-key", "service apikey");
  const body = JSON.parse(stored.body);
  assert(body.p_user_id === userId, "user");
  assert(body.p_refresh_token === refreshToken, "stored token");
});

Deno.test("unauthenticated store does not call Apple", async () => {
  const calls: Call[] = [];
  const deps = storeDepsFrom(platformEnv(), fakeFetch(calls, { userStatus: 401 }));
  const response = await handleStoreAppleRefreshToken(jsonRequest({
    authorization_code: authorizationCode,
  }), deps);
  assert(response.status === 401, "status");
  assert(!calls.some((call) => call.url.includes("appleid.apple.com")), "no apple");
});

Deno.test("revoke failure still deletes the account and the stored token", async () => {
  const calls: Call[] = [];
  const logs: string[] = [];
  const deps = deleteDepsFrom(platformEnv(), fakeFetch(calls, {
    appleStatus: 400,
    appleBody: { error: refreshToken },
  }));
  deps.log = (message) => logs.push(message);
  const response = await handleDeleteAccount(jsonRequest({}), deps);
  const text = await response.text();
  assert(response.status === 200, "status");
  assert(text === '{"ok":true,"apple_revoke_failed":true}', text);
  assert(!text.includes(refreshToken), "token in response");
  assert(calls.some((call) => call.url === "https://appleid.apple.com/auth/revoke"), "revoke");
  const revoke = calls.find((call) => call.url.includes("/auth/revoke"));
  assert(revoke?.body.includes("token_type_hint=refresh_token"), "hint");
  assert(revoke?.body.includes(`token=${encodeURIComponent(refreshToken)}`) ||
    revoke?.body.includes(`token=${refreshToken}`), "revoke token");
  const deleted = calls.find((call) => call.url.endsWith("/rpc/delete_own_account"));
  assert(deleted, "delete account");
  assert(deleted.authorization === "Bearer service-key", "service role");
  assert(deleted.apikey === "service-key", "service apikey");
  assert(JSON.parse(deleted.body).p_user_id === userId, "resolved user id");
  assert(!deleted.authorization.includes(userAuthorization()), "not the user jwt");
  const removed = calls.find((call) => call.url.endsWith("/rpc/delete_apple_refresh_token"));
  assert(removed, "delete token");
  assert(removed.authorization === "Bearer service-key", "service role delete");
  const revokeIndex = calls.findIndex((call) => call.url.includes("/auth/revoke"));
  const deleteIndex = calls.findIndex((call) => call.url.endsWith("/rpc/delete_own_account"));
  assert(deleteIndex >= 0 && revokeIndex > deleteIndex, "delete then revoke");
  assert(!logs.join("\n").includes(refreshToken), "token logged");
  assert(logs.some((line) => line.includes("status=400")), "failure logged");
});

Deno.test("account deletion failure keeps the stored token", async () => {
  const calls: Call[] = [];
  const deps = deleteDepsFrom(platformEnv(), fakeFetch(calls, { deleteAccountStatus: 400 }));
  const response = await handleDeleteAccount(jsonRequest({}), deps);
  assert(response.status === 500, "status");
  assert(await response.text() === '{"ok":false}', "body");
  assert(!calls.some((call) => call.url.endsWith("/rpc/delete_apple_refresh_token")), "token kept");
  assert(!calls.some((call) => call.url.includes("appleid.apple.com")), "apple untouched");
});

Deno.test("missing apple secrets do not block account deletion", async () => {
  const calls: Call[] = [];
  const env = platformEnv();
  delete (env as { APPLE_PRIVATE_KEY?: string }).APPLE_PRIVATE_KEY;
  const deps = deleteDepsFrom(env, fakeFetch(calls, {}));
  const logs: string[] = [];
  deps.log = (message) => logs.push(message);
  const response = await handleDeleteAccount(jsonRequest({}), deps);
  assert(response.status === 200, "status");
  assert(
    await response.text() === '{"ok":true,"apple_revoke_failed":true}',
    "revoke flagged",
  );
  assert(!calls.some((call) => call.url.includes("appleid.apple.com")), "no apple");
  assert(calls.some((call) => call.url.endsWith("/rpc/delete_own_account")), "deleted");
  assert(logs.some((line) => line.includes("secrets_missing")), "logged");
});

Deno.test("no stored apple token deletes without the revoke flag", async () => {
  const calls: Call[] = [];
  const deps = deleteDepsFrom(platformEnv(), fakeFetch(calls, {
    refreshToken: null,
    appleLinked: false,
  }));
  const response = await handleDeleteAccount(jsonRequest({}), deps);
  assert(response.status === 200, "status");
  assert(await response.text() === '{"ok":true}', "no flag");
  assert(!calls.some((call) => call.url.includes("appleid.apple.com")), "no apple");
  assert(calls.some((call) => call.url.includes("/auth/v1/admin/users/")), "identity lookup");
  assert(calls.some((call) => call.url.endsWith("/rpc/delete_own_account")), "deleted");
});

Deno.test("apple user without a stored token is told to unlink manually", async () => {
  const calls: Call[] = [];
  const deps = deleteDepsFrom(platformEnv(), fakeFetch(calls, {
    refreshToken: null,
    appleLinked: true,
  }));
  const response = await handleDeleteAccount(jsonRequest({}), deps);
  assert(response.status === 200, "status");
  assert(await response.text() === '{"ok":true,"apple_revoke_failed":true}', "flag");
  assert(!calls.some((call) => call.url.includes("appleid.apple.com")), "no apple");
  const lookup = calls.findIndex((call) => call.url.includes("/auth/v1/admin/users/"));
  const deleted = calls.findIndex((call) => call.url.endsWith("/rpc/delete_own_account"));
  assert(lookup >= 0 && deleted > lookup, "lookup before delete");
});

Deno.test("identity lookup failure without a token does not set the flag", async () => {
  const calls: Call[] = [];
  const logs: string[] = [];
  const deps = deleteDepsFrom(platformEnv(), fakeFetch(calls, {
    refreshToken: null,
    appleLinked: null,
  }));
  deps.log = (message) => logs.push(message);
  const response = await handleDeleteAccount(jsonRequest({}), deps);
  assert(response.status === 200, "status");
  assert(await response.text() === '{"ok":true}', "no flag");
  assert(!calls.some((call) => call.url.includes("appleid.apple.com")), "no apple");
  assert(logs.some((line) => line.includes("apple identity lookup failed")), "logged");
});

Deno.test("admin user json reports an apple identity", () => {
  assert(
    appleIdentityInAdminUser(JSON.stringify({
      identities: [{ provider: "apple" }],
    })) === true,
    "identity",
  );
  assert(
    appleIdentityInAdminUser(JSON.stringify({
      app_metadata: { providers: ["google"] },
    })) === false,
    "google",
  );
  assert(appleIdentityInAdminUser("not-json") === null, "parse");
});

Deno.test("a body user id does not replace the authenticated user", async () => {
  const calls: Call[] = [];
  const deps = deleteDepsFrom(platformEnv(), fakeFetch(calls, {}));
  const response = await handleDeleteAccount(jsonRequest({
    p_user_id: "22222222-2222-4222-8222-222222222222",
  }), deps);
  assert(response.status === 200, "status");
  const deleted = calls.find((call) => call.url.endsWith("/rpc/delete_own_account"));
  assert(deleted, "delete account");
  assert(JSON.parse(deleted.body).p_user_id === userId, "auth user");
  assert(deleted.authorization === "Bearer service-key", "service role");
});

Deno.test("direct revoke failure still reaches delete_own_account", async () => {
  let deleted = false;
  let tokenDeleted = false;
  let revoked = false;
  const deps: DeleteDeps = {
    log: () => {},
    resolveUserId: async () => userId,
    readToken: async () => refreshToken,
    appleLinked: async () => false,
    revoke: async () => {
      revoked = true;
      if (!deleted) {
        throw new Error("revoked before delete");
      }
      throw new Error("network");
    },
    deleteAccount: async () => {
      deleted = true;
    },
    deleteStoredToken: async () => {
      tokenDeleted = true;
    },
  };
  const result = await deleteThenRevokeAccount({
    userId,
    deps,
  });
  assert(result === "deleted_revoke_failed", result);
  assert(deleted, "account deleted");
  assert(revoked, "revoke after delete");
  assert(tokenDeleted, "token deleted");
});

Deno.test("account deletion failure does not revoke", async () => {
  let revoked = false;
  const deps: DeleteDeps = {
    log: () => {},
    resolveUserId: async () => userId,
    readToken: async () => refreshToken,
    appleLinked: async () => true,
    revoke: async () => {
      revoked = true;
      return { ok: true, status: 200, errorCode: "" };
    },
    deleteAccount: async () => {
      throw new Error("db");
    },
    deleteStoredToken: async () => {
      throw new Error("vault should stay");
    },
  };
  const result = await deleteThenRevokeAccount({
    userId,
    deps,
  });
  assert(result === "delete_failed", result);
  assert(!revoked, "apple untouched");
});

function jsonRequest(body: unknown): Request {
  return new Request("https://fn.local/fn", {
    method: "POST",
    headers: {
      Authorization: userAuthorization(),
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

function fakeFetch(
  calls: Call[],
  options: {
    userStatus?: number;
    appleStatus?: number;
    appleBody?: unknown;
    deleteAccountStatus?: number;
    refreshToken?: string | null;
    appleLinked?: boolean | null;
  },
): FetchLike {
  return async (input, init) => {
    calls.push({
      url: input,
      authorization: header(init, "Authorization"),
      apikey: header(init, "apikey"),
      body: typeof init?.body === "string" ? init.body : "",
    });
    if (input.includes("/auth/v1/admin/users/")) {
      if (options.appleLinked === null) {
        return new Response("{}", { status: 500 });
      }
      const linked = options.appleLinked === true;
      return new Response(JSON.stringify({
        id: userId,
        identities: [{ provider: linked ? "apple" : "email" }],
      }), { status: 200 });
    }
    if (input.endsWith("/auth/v1/user")) {
      if (options.userStatus && options.userStatus !== 200) {
        return new Response("{}", { status: options.userStatus });
      }
      return new Response(JSON.stringify({ id: userId }), { status: 200 });
    }
    if (input.endsWith("/rpc/read_apple_refresh_token")) {
      const token = "refreshToken" in options ? options.refreshToken : refreshToken;
      return new Response(JSON.stringify(token), { status: 200 });
    }
    if (input.includes("appleid.apple.com")) {
      return new Response(JSON.stringify(options.appleBody ?? {}), {
        status: options.appleStatus ?? 200,
      });
    }
    if (input.endsWith("/rpc/delete_own_account")) {
      return new Response(null, { status: options.deleteAccountStatus ?? 204 });
    }
    return new Response(null, { status: 204 });
  };
}

Deno.test("web preflight allows only the app origins", async () => {
  const calls: Call[] = [];
  const deps = deleteDepsFrom(platformEnv(), fakeFetch(calls, {}));
  const allowed = await handleDeleteAccount(
    new Request("https://fn.local/fn", {
      method: "OPTIONS",
      headers: { Origin: publishedWebOrigin },
    }),
    deps,
  );
  assert(allowed.status === 204, "status");
  assert(
    allowed.headers.get("Access-Control-Allow-Origin") === publishedWebOrigin,
    "origin echoed",
  );
  assert(
    allowed.headers.get("Access-Control-Allow-Methods")?.includes("POST"),
    "methods",
  );
  assert(
    allowed.headers.get("Access-Control-Allow-Origin") !== "*",
    "not wildcard",
  );
  assert(calls.length === 0, "preflight does no work");

  const local = await handleStoreAppleRefreshToken(
    new Request("https://fn.local/fn", {
      method: "OPTIONS",
      headers: { Origin: "http://127.0.0.1:54321" },
    }),
    storeDepsFrom(platformEnv(), fakeFetch([], {})),
  );
  assert(local.status === 204, "local status");
  assert(
    local.headers.get("Access-Control-Allow-Origin") === "http://127.0.0.1:54321",
    "local origin",
  );

  const denied = await handleDeleteAccount(
    new Request("https://fn.local/fn", {
      method: "OPTIONS",
      headers: { Origin: "https://evil.example" },
    }),
    deps,
  );
  assert(denied.status === 403, "denied");
  assert(denied.headers.get("Access-Control-Allow-Origin") === null, "no header");
});

Deno.test("a web delete response carries the preview origin", async () => {
  const calls: Call[] = [];
  const deps = deleteDepsFrom(platformEnv(), fakeFetch(calls, {}));
  const response = await handleDeleteAccount(
    new Request("https://fn.local/fn", {
      method: "POST",
      headers: {
        Authorization: userAuthorization(),
        "Content-Type": "application/json",
        Origin: publishedWebOrigin,
      },
      body: "{}",
    }),
    deps,
  );
  assert(response.status === 200, "status");
  assert(
    response.headers.get("Access-Control-Allow-Origin") === publishedWebOrigin,
    "cors",
  );
  const native = await handleDeleteAccount(jsonRequest({}), deps);
  assert(native.headers.get("Access-Control-Allow-Origin") === null, "native");
});

function toArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  const copy = new ArrayBuffer(bytes.byteLength);
  new Uint8Array(copy).set(bytes);
  return copy;
}

function base64UrlBytes(input: string): Uint8Array {
  const padded = input.replaceAll("-", "+").replaceAll("_", "/") +
    "=".repeat((4 - (input.length % 4)) % 4);
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}
