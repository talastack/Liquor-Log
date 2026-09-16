// A published "what's open", as a page.
//
// GET /functions/v1/menu/<slug> reads the menus row for that slug with the
// service role -- the table has no public read policy, so the slug is the
// only way in and it is twelve characters nobody can guess -- and renders
// it as plain HTML in the app's Cellar look. No script, no tracking, no
// prices: the body is the same text the app shares.
//
// Deploy from the repo root, once:
//
//     supabase functions deploy menu --no-verify-jwt
//
// --no-verify-jwt because the page is opened by people without the app.
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided to every function
// by the platform; nothing needs setting.

import { createClient } from "npm:@supabase/supabase-js@2";

const html = (title: string, body: string, published: string) => `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>${title}</title>
<style>
  :root { color-scheme: dark; }
  body { margin: 0; background: #0E1613; color: #EAF0E9; font: 17px/1.5 -apple-system, "Helvetica Neue", Arial, sans-serif; }
  main { max-width: 32rem; margin: 0 auto; padding: 2.5rem 1.25rem 4rem; }
  h1 { font: 600 1.75rem/1.2 Georgia, "Times New Roman", serif; margin: 0 0 .25rem; }
  .when { color: #A9B8AC; font-size: .85rem; margin: 0 0 1.5rem; }
  hr { border: 0; border-top: 2px solid #C97B4A; margin: 0 0 1.25rem; }
  pre { white-space: pre-wrap; font: inherit; margin: 0; }
  footer { color: #7C8C80; font-size: .8rem; margin-top: 2.5rem; }
</style>
</head>
<body>
<main>
  <h1>${title}</h1>
  <p class="when">${published}</p>
  <hr>
  <pre>${body}</pre>
  <footer>Open bottles only. No prices.</footer>
</main>
</body>
</html>`;

const escape = (text: string) =>
  text.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c] as string));

Deno.serve(async (request) => {
  const slug = new URL(request.url).pathname.split("/").filter(Boolean).pop() ?? "";
  if (!/^[a-z0-9]{6,64}$/.test(slug)) {
    return new Response("Not found", { status: 404 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data, error } = await supabase
    .from("menus")
    .select("title, body, published_at, deleted_at")
    .eq("slug", slug)
    .maybeSingle();

  if (error || !data || data.deleted_at) {
    return new Response("Not found", { status: 404 });
  }

  const published = new Date(Number(data.published_at)).toLocaleDateString("en-US", {
    year: "numeric", month: "long", day: "numeric",
  });
  const page = html(escape(data.title), escape(data.body), `Published ${published}`);
  return new Response(page, {
    status: 200,
    headers: { "content-type": "text/html; charset=utf-8", "cache-control": "public, max-age=60" },
  });
});
