# MoneyBag Admin API v2 — Cloudflare Worker (Hono.js + D1)

Node.js সার্ভার পুরোপুরি বদলে এখন একটাই Cloudflare Worker — ফ্রি প্লানেই চলে,
D1 (SQL) ডেটাবেসে সব ডেটা স্থায়ীভাবে থাকে, দ্রুত (edge), আর আলাদা কোনো সার্ভার
রাখতে হয় না।

> **v2.0.0:** রেট লিমিটিং + timing-safe কী যাচাই + পে-লোড ভ্যালিডেশন + CORS
> অ্যালোলিস্ট + ETag/304 ক্যাশিং + deep health + `/docs` ও `/openapi.json` +
> পুশে স্ট্যাবল কার্সর পেজিং + single-flight OAuth টোকেন। ৩৭টা অটো-টেস্ট সহ
> (`npm test`)। পুরনো ডিপ্লয়েড অ্যাপ/ড্যাশবোর্ডের সাথে ১০০% ব্যাকওয়ার্ড-কম্প্যাটিবল।

## ফিচার

- **App Config** — force-update / maintenance / min-version (এখন ভ্যালিডেটেড)
- **Ads Control** — AdMob on/off + banner/interstitial/**rewarded** unit IDs (remote)
- **Announcements** — অ্যাপের ড্যাশবোর্ডে দেখানো নোটিশ, এখন **সময়সীমা** (startsAt/endsAt) সহ
- **Users** — Google Sign-In-এর পর অ্যাপ থেকে `/api/v1/users/sync`-এ
  Name, Email, UID + FCM Token যায় এবং D1-তে জমা থাকে (shape-ভ্যালিডেটেড + রেট-লিমিটেড)
- **Targeted Push** — নির্দিষ্ট ইউজারের FCM টোকেন দিয়ে শুধু তাকে নোটিফিকেশন
- **Global Push** — সব ইউজারকে (40 জন করে ব্যাচে; এখন কার্সর পেজিং —
  মাঝপথে লগইন হলেও কেউ skip/duplicate হয় না)
- **Docs** — ডিপ্লয়ের পর `/docs` (HTML) ও `/openapi.json` (OpenAPI 3.1)

## v2-এর সিকিউরিটি সেটিংস (ঐচ্ছিক vars)

`wrangler.toml`-এর `[vars]`-এ সেট করা যায়:

| Var | ডিফল্ট | কাজ |
|---|---|---|
| `ALLOWED_ORIGINS` | `""` (=সব origin) | CORS অ্যালোলিস্ট, কমা-সেপারেটেড। ড্যাশবোর্ডের ডোমেইন ঠিক হলে সেট করুন |
| `RL_PUBLIC_PER_MIN` | `240` | পাবলিক GET প্রতি IP প্রতি মিনিটে |
| `RL_SYNC_PER_MIN` | `30` | users/sync (আনঅথেন্টিকেটেড রাইট) — কম রাখুন |
| `RL_ADMIN_PER_MIN` | `600` | অ্যাডমিন রাউট (পুশ লুপ ধারণ করতে হবে) |

> হার্ড-গ্যারান্টি রেট লিমিট চাইলে Cloudflare WAF rate-limit rule যোগ করুন
> (isolate-ভিত্তিক লিমিটার best-effort)।

কী রোটেশন: `ADMIN_API_KEYS` সিক্রেটে অতিরিক্ত কী (কমা-সেপারেটেড) দিন →
ড্যাশবোর্ডে নতুন কী বসান → পুরনো `ADMIN_API_KEY` বদলে দিন। কোনো ডাউনটাইম নেই।

## ডিপ্লয় (৬ ধাপ, ~১০ মিনিট)

```bash
cd worker
npm install                       # ১ hono + wrangler

npx wrangler login                # ২ ব্রাউজারে Cloudflare লগইন

npx wrangler d1 create moneybag-db
#    → যে database_id ছাপা আসবে সেটা wrangler.toml-এ REPLACE_WITH_YOUR_D1_DATABASE_ID-এর জায়গায় বসাও (৩)

npx wrangler d1 execute moneybag-db --remote --file=schema.sql   # ৪ টেবিল তৈরি

npx wrangler secret put ADMIN_API_KEY        # ৫-ক — অ্যাডমিন প্যানেলের লগইন কী (openssl rand -hex 32)
npx wrangler secret put FCM_SERVICE_ACCOUNT  # ৫-খ — নিচে দেখো
npx wrangler deploy                          # ৬
```

**আগের v1 ডেটাবেস আপগ্রেড:** `npx wrangler d1 execute moneybag-db --remote
--file=migrations/0002_indexes.sql` — নতুন ইনডেক্স যোগ হবে, ডেটা অক্ষত।

ডিপ্লয় শেষে যে URL পাবে (যেমন `https://moneybag-api.your-name.workers.dev`) —
এটাই অ্যাপে একমাত্র হার্ডকোড করার API URL (`moneybag_flutter/lib/core/config.dart`
→ `adminApiBaseUrl`)।

## FCM_SERVICE_ACCOUNT কোথায় পাবে

1. https://console.firebase.google.com → প্রজেক্ট → ⚙️ Project settings
2. **Service accounts** ট্যাব → **Generate new private key** → JSON ফাইল নামবে
3. ফাইলটার **পুরো JSON** (সব এক লাইনে) কপি করে:
   `npx wrangler secret put FCM_SERVICE_ACCOUNT` চালিয়ে পেস্ট করো → Enter

> পুশ পাঠাতে হলে অবশ্যই Firebase প্রজেক্টে Cloud Messaging সেটআপ থাকতে হবে
> (Android app + `google-services.json` অ্যাপে বসানো — অ্যাপের DEPLOY.md দেখো)।

## লোকাল টেস্ট

```bash
npx wrangler d1 execute moneybag-db --local --file=schema.sql
npm run dev        # http://localhost:8787  (ডিপ্লয়ের আগে /docs এখানেই দেখা যায়)
npm run typecheck  # tsc --noEmit
npm test           # vitest — ৩৭টা ভ্যালিডেশন/ইউনিট টেস্ট
```

লোকাল সিক্রেট (`.dev.vars` ফাইল, কমিট করবেন না):

```
ADMIN_API_KEY=dev-key-change-me
FCM_SERVICE_ACCOUNT={"project_id":"..."}
```

## API এক নজরে

ডিপ্লয়ের পর `https://…workers.dev/docs`-এ সম্পূর্ণ ডকুমেন্টেশন (সব রেসপন্স-শেপ, লিমিট,
এরর কোড সহ)। সংক্ষেপে:

| Method | Path | Key লাগবে? | কাজ |
|---|---|---|---|
| GET | `/`, `/health` (`?deep=1` → D1 পিং) | না | info/health |
| GET | `/docs`, `/openapi.json` | না | ডকুমেন্টেশন |
| GET | `/api/v1/app` | না | config + ads + announcements (অ্যাপ বুটে এক কল; ETag/304 সহ) |
| GET | `/api/v1/config` `/api/v1/ads` `/api/v1/announcements` | না | আলাদা আলাদা |
| POST | `/api/v1/users/sync` | না | ইউজার + FCM টোকেন আপসার্ট (ভ্যালিডেটেড, ৩০/min) |
| GET | `/api/v1/admin/*` (login, overview, users, config, ads, push/log, announcements) | **হ্যাঁ** | ড্যাশবোর্ড |
| POST | `/api/v1/admin/users/push` | **হ্যাঁ** | টার্গেটেড পুশ |
| POST | `/api/v1/admin/push` | **হ্যাঁ** | গ্লোবাল পুশ (offset বা cursor পেজিং) |
| PUT | `/api/v1/admin/config` `/api/v1/admin/ads` | **হ্যাঁ** | কনফিগ/অ্যাডস (strict ভ্যালিডেশন) |
| POST/PATCH/DELETE | `/api/v1/admin/announcements…` | **হ্যাঁ** | নোটিশ ম্যানেজ (সময়সীমা সহ) |

curl উদাহরণ:

```bash
BASE="https://moneybag-api.your-name.workers.dev"
KEY="your-admin-api-key"

curl "$BASE/health"
curl "$BASE/api/v1/app"
curl -X POST "$BASE/api/v1/users/sync" -H 'Content-Type: application/json' \
  -d '{"uid":"test-1","email":"a@b.com","name":"Test","fcmToken":"","platform":"android"}'
curl -H "x-api-key: $KEY" "$BASE/api/v1/admin/overview"
curl -H "x-api-key: $KEY" "$BASE/api/v1/admin/users"
curl -X POST "$BASE/api/v1/admin/push" -H "x-api-key: $KEY" \
  -H 'Content-Type: application/json' -d '{"title":"নমস্কার","body":"সবাইকে স্বাগতম!"}'
```
