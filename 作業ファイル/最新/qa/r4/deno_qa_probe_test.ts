import { handleDeleteAccount, isAllowedWebOrigin, type DeleteDeps } from "./apple_account.ts";
function deps(o: Partial<DeleteDeps>, log: string[], calls: string[]): DeleteDeps {
  return {
    log: (m) => log.push(m),
    resolveUserId: async (a) => (a === "Bearer good" ? "11111111-1111-4111-8111-111111111111" : null),
    readToken: async () => { calls.push("read"); return "tok"; },
    appleLinked: async () => { calls.push("linked"); return true; },
    revoke: async (t) => { calls.push("revoke:" + t); return { ok: true, status: 200, errorCode: "" }; },
    deleteAccount: async () => { calls.push("delete"); },
    deleteStoredToken: async () => { calls.push("deltok"); },
    ...o,
  } as DeleteDeps;
}
async function run(name: string, init: RequestInit & { origin?: string }, o: Partial<DeleteDeps> = {}) {
  const log: string[] = [], calls: string[] = [];
  const h = new Headers(init.headers); if (init.origin) h.set("Origin", init.origin);
  const r = await handleDeleteAccount(new Request("https://x/functions/v1/delete-account", { method: init.method, headers: h }), deps(o, log, calls));
  console.log(`PROBE ${name}: status=${r.status} ACAO=${r.headers.get("Access-Control-Allow-Origin")} body=${r.status===204||r.status===403?"":await r.text()} calls=${calls.join(">")} log=${log.join("|")}`);
}
Deno.test("qa probes", async () => {
  for (const o of ["https://naruto-aii.github.io","https://naruto-aii.github.io.evil.com","https://evil.com","http://localhost:3000","http://127.0.0.1:8080","https://localhost","http://localhost.evil.com","null","http://user:pw@localhost"]) console.log(`ORIGIN ${o} allowed=${isAllowedWebOrigin(o)}`);
  await run("OPTIONS allowed", { method: "OPTIONS", origin: "https://naruto-aii.github.io" });
  await run("OPTIONS evil", { method: "OPTIONS", origin: "https://evil.com" });
  await run("POST evil origin good auth", { method: "POST", origin: "https://evil.com", headers: { Authorization: "Bearer good" } });
  await run("POST allowed no auth", { method: "POST", origin: "https://naruto-aii.github.io" });
  await run("POST allowed bad auth", { method: "POST", origin: "https://naruto-aii.github.io", headers: { Authorization: "Bearer bad" } });
  await run("GET allowed", { method: "GET", origin: "https://naruto-aii.github.io", headers: { Authorization: "Bearer good" } });
  await run("normal", { method: "POST", headers: { Authorization: "Bearer good" } });
  await run("revoke fails after delete", { method: "POST", headers: { Authorization: "Bearer good" } }, { revoke: async () => ({ ok: false, status: 400, errorCode: "invalid_grant" }) });
  await run("revoke throws", { method: "POST", headers: { Authorization: "Bearer good" } }, { revoke: async () => { throw new Error("x"); } });
  await run("delete fails", { method: "POST", headers: { Authorization: "Bearer good" } }, { deleteAccount: async () => { throw new Error("x"); } });
  await run("no token, apple linked", { method: "POST", headers: { Authorization: "Bearer good" } }, { readToken: async () => null });
  await run("no token, not linked", { method: "POST", headers: { Authorization: "Bearer good" } }, { readToken: async () => null, appleLinked: async () => false });
  await run("read throws, linked lookup fails", { method: "POST", headers: { Authorization: "Bearer good" } }, { readToken: async () => { throw new Error("x"); }, appleLinked: async () => null });
  await run("deleteStoredToken fails", { method: "POST", headers: { Authorization: "Bearer good" } }, { deleteStoredToken: async () => { throw new Error("x"); } });
});
