// Hello Fitness · AI 代理 Edge Function
//
// 作用：App 不再直接调 DeepSeek（避免把 API Key 暴露给客户端），
// 而是调这个函数，由服务端用 Secret 里的 DEEPSEEK_API_KEY 转发。
//
// 部署（项目根目录）：
//   npx supabase login
//   npx supabase link --project-ref zifruhulyrflbqecvxnt
//   npx supabase secrets set DEEPSEEK_API_KEY=sk-xxxx
//   npx supabase functions deploy ai-chat
//
// 请求格式（App 发来）：
//   { model, messages, temperature, max_tokens, response_format? }
// 响应：直接把 DeepSeek 的响应原样返回给 App。

import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  // 预检请求直接放行
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // ── 1. 校验登录态 ──
    const authHeader = req.headers.get("Authorization") ?? "";
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const {
      data: { user },
    } = await supabaseClient.auth.getUser();
    if (!user) {
      return json({ error: "未登录" }, 401);
    }

    // ── 2. 解析请求 ──
    const body = await req.json();
    const { model, messages, temperature, max_tokens, response_format } = body;

    if (!Array.isArray(messages) || messages.length === 0) {
      return json({ error: "messages 不能为空" }, 400);
    }

    const key = Deno.env.get("DEEPSEEK_API_KEY");
    if (!key) {
      return json({ error: "服务端未配置 DEEPSEEK_API_KEY" }, 500);
    }

    // ── 3. 转发到 DeepSeek ──
    const deepseekBody: Record<string, unknown> = {
      model: model || "deepseek-chat",
      messages,
      temperature,
      max_tokens,
    };
    if (response_format) {
      deepseekBody.response_format = response_format;
    }

    const res = await fetch("https://api.deepseek.com/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${key}`,
      },
      body: JSON.stringify(deepseekBody),
    });

    const data = await res.json();
    return new Response(JSON.stringify(data), {
      status: res.status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return json({ error: e.message ?? "服务内部错误" }, 500);
  }
});

function json(obj: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
