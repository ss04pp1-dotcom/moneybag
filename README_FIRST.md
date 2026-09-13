# MoneyBag v2.2.5 — ফাইনাল প্রোডাকশন প্যাকেজ (এখান থেকে শুরু করুন)

এই একটা প্যাকেজেই পুরো MoneyBag-এর সবকিছু আছে — **অ্যাপ + API + অ্যাডমিন ড্যাশবোর্ড**।
সবকিছু ডিপ্লয়-রেডি কোড হিসেবে যাচাই করা (ভার্সন v2.2.5+2205)।

> **সম্পূর্ণ ডিপ্লয়-টু-লঞ্চ গাইড:** এই zip-এর রুটে `PRODUCTION_GUIDE.pdf` — ৯টি অধ্যায়ে
> ধাপে ধাপে সব (তিনটি কম্পোনেন্ট ডিপ্লয়, কনফিগার, সিকিউরিটি চেকলিস্ট, টেস্ট, ট্রাবলশুটিং)।

> **v2.2.4 → v2.2.5-এ যা বদলেছে (রিয়েল-ডিভাইস ফিডব্যাক রাউন্ড):**
> - **ক্যাটাগরি বাজেট ফিক্স (ক্রিটিক্যাল):** "+ বাজেট যোগ করুন" শিটে ক্যাটাগরি চিপ দেখাত না আর সেভও ভুল জায়গায় হতো — একটা লজিক-বাগের কারণে সব বাজেট "সামগ্রিক" হয়ে যেত। এখন ঠিক: চিপ দেখায়, আলাদা ক্যাটাগরি বাজেট সেভ হয়
> - **খরচ/আয়ের নতুন সেভ-লজিক:** উপরের বাক্সে লিখুন কিসে খরচ হলো (যেমন: রিকশা ভাড়া) — লেখাটাই ক্যাটাগরি হয়ে সেভ হবে; বাক্স ফাঁকা রাখলে নিচ থেকে ক্যাটাগরি বাছাই করতে হবে; নোট পুরোপুরি ঐচ্ছিক
> - **নোটিফিকেশন ফিক্স:** "সাপ্তাহিক সারসংক্ষেপ" আসলে প্রতিদিন আসছিল (repeat-rule বাগ) — এখন সপ্তাহে একবার (শুক্রবার); মিসড-রিমাইন্ডারের বডিতেও লাইভ সংখ্যা
> - **ব্যাকআপ হার্ডেনিং:** রিস্টোরে ক্যাটাগরি/বাজেট missing-key হলে invisible হয়ে যেত — এখন কলাম-ডিফল্ট মান্য করে; ডিফল্ট ক্যাটাগরি রিঅ্যাক্টিভেট সেলফ-হিল
> - **What's-নিউ গাইড:** ভার্সন-গেটিং আটকে ছিল (config এ ২.১.২ পড়া ছিল) — এখন আপগ্রেডের পর গাইড দেখাবে
> - আগের সব (v2.2.3 উইজেট/নোটিফিকেশন/ট্যাপ ফিক্স, v2.2.4 ভাষা অডিট, v2.2.0 সিকিউরিটি) সবই আছে
> বিস্তারিত: `CHANGELOG.md`

## প্যাকেজে যা যা আছে

| ফোল্ডার | কী | কোথায় চলবে |
|---|---|---|
| `moneybag_flutter/` | মোবাইল অ্যাপ (Flutter, বাংলা + BDT ৳, অফলাইন-ফার্স্ট) | আপনার কম্পিউটারে বিল্ড → Play Store / সরাসরি APK |
| `moneybag-cloudflare/worker/` | **API সার্ভার** (Hono.js + D1 SQL) | **Cloudflare Workers** (ফ্রি প্ল্যানেই চলে) |
| `moneybag-cloudflare/admin/` | **অ্যাডমিন ড্যাশবোর্ড** (React + Tailwind — dist আগেই বিল্ট) | **Cloudflare Pages** (ফ্রি) |

---

## কোথায় কী বসাবেন — পুরো ফ্লো এক নজরে

```
১ Worker ডিপ্লয় করুন  →  ২ Admin ডিপ্লয় করুন  →  ৩ অ্যাপে ৪টা জিনিস বসিয়ে রিবিল্ড  →  ৪ টেস্ট
        └── API URL পাবেন ────────┤  └── Worker URL + Admin Key দিয়ে লগইন
                                    └── সেই URL অ্যাপে বসবে
```

### যা যা আগে থেকে লাগবে

- **Cloudflare অ্যাকাউন্ট** (ফ্রি) — https://dash.cloudflare.com/sign-up
- **Node.js 18+** কম্পিউটারে (Worker/Admin ডিপ্লয়ের কমান্ড চালাতে)
- অ্যাপ বিল্ড করতে চাইলে **Flutter SDK 3.24+** + Android Studio/SDK
- (পুশ চালু করতে চাইলে) **Firebase প্রজেক্ট** — https://console.firebase.google.com

---

## ১. API — Cloudflare Worker ডিপ্লয় (৬ কমান্ড, ~১০ মিনিট)

```bash
cd moneybag-cloudflare/worker
npm install
npx wrangler login                              # ব্রাউজারে Cloudflare লগইন

npx wrangler d1 create moneybag-db              # → যে database_id ছাপা আসবে কপি করুন

npx wrangler d1 execute moneybag-db --remote --file=schema.sql

npx wrangler secret put ADMIN_API_KEY           # নিজের লম্বা র‍্যান্ডম কী: openssl rand -hex 32
npx wrangler secret put FCM_SERVICE_ACCOUNT     # Firebase service-account JSON এক লাইনে (নিচে দেখুন)
npx wrangler deploy
```

**আগের v1 ডেটাবেস আছে?** শুধু `npx wrangler d1 execute moneybag-db --remote --file=migrations/0002_indexes.sql` চালান — নতুন ইনডেক্স বসে যাবে, ডেটা অক্ষত থাকবে।

**`database_id` বসানোর একটাই জায়গা:** `worker/wrangler.toml`-এ `REPLACE_WITH_YOUR_D1_DATABASE_ID` এর জায়গায় কপি করা ID।

**FCM_SERVICE_ACCOUNT কোথায় পাবেন (পুশের জন্য):**
Firebase Console → Project settings → **Service accounts** → *Generate new private key* →
ফাইলের **পুরো JSON** কপি করে পেস্ট (এক লাইনেই হোক না কেন, ঠিক আছে)।
পুশ দরকার না হলে এই সিক্রেট না দিলেও বাকি সব কাজ করবে।

ডিপ্লয়ের শেষে যে URL পাবেন (যেমন `https://moneybag-api.apnar-name.workers.dev`) — **লিখে রাখুন, ধাপ ৩-এ লাগবে।**
ডিপ্লয়ের পর ব্রাউজারে `https://…workers.dev/docs` খুললে পুরো API-র ডকুমেন্টেশন দেখতে পাবেন।

বিস্তারিত: `worker/README.md`

## ২. অ্যাডমিন ড্যাশবোর্ড — Cloudflare Pages (৩ কমান্ড)

```bash
cd moneybag-cloudflare/admin
npm install && npm run build                    # dist/ নতুন করে তৈরি হবে
npx wrangler pages deploy dist --project-name moneybag-admin
```

ব্রাউজারে যে URL পাবেন (যেমন `https://moneybag-admin.pages.dev`) খুলে:
1. **Worker API URL** = ধাপ ১-এর URL
2. **Admin API Key** = `ADMIN_API_KEY` সিক্রেটে যা দিয়েছেন
3. Sign in → ইউজার, পুশ, নোটিশ, Ads সব এখান থেকে কন্ট্রোল হবে।

> **টিপ:** Pages-এর ডোমেইন ঠিক হয়ে গেলে Worker-এর `wrangler.toml`-এ `ALLOWED_ORIGINS = "https://moneybag-admin.pages.dev"` সেট করে একবার `npx wrangler deploy` দিন — CORS এখন শুধু আপনার ড্যাশবোর্ড থেকেই admin কল নেবে।

বিস্তারিত: `admin/README.md`

## ৩. অ্যাপে বসানো — ৪টা জিনিস (তারপর একবার রিবিল্ড)

| # | কী | ফাইল | কী বসাবেন |
|---|---|---|---|
| 1 | **Worker API URL** | `moneybag_flutter/lib/core/config.dart` → `adminApiBaseUrl` | ধাপ ১-এর আসল URL (`https://moneybag-api.YOUR-SUBDOMAIN.workers.dev` এর জায়গায়)। অ্যাপের **সব** API কল এই একটাই URL দিয়ে চলে |
| 2 | **Google Web Client ID** | একই ফাইল → `googleWebClientId` | Google Cloud Console → Credentials → Web application টাইপের Client ID (Android SHA-1 যোগ করা থাকতে হবে)। Google লগইন + Drive অটো-ব্যাকআপ চালু হয় |
| 3 | **google-services.json** | `moneybag_flutter/android/app/google-services.json` | Firebase থেকে আসল ফাইল দিয়ে রিপ্লেস (Android অ্যাপ, প্যাকেজ `bd.moneybag.moneybag`) → FCM পুশ চালু |
| 4 | **AdMob App ID** (অ্যাড চালালে) | `android/app/src/main/AndroidManifest.xml` (APPLICATION_ID) | আসল AdMob App ID (`ca-app-pub-XXXX~YYYY`)। Unit ID গুলো পরে ড্যাশবোর্ড থেকে রিমোটলি বদলানো যায় |

**রিলিজ সাইনিং (Play Store-এর জন্য):** `moneybag_flutter/android/keystore.properties.example` দেখুন —
একবার `keytool` দিয়ে কী বানিয়ে `android/keystore.properties` বানালে release APK/AAB অটো-সাইন হবে
(v2.2.0-এর আগে debug কী দিয়ে সাইন হতো, Play Store সেটা নেয় না)।

তারপর:

```bash
cd moneybag_flutter
flutter pub get
flutter build apk --release        # build/app/outputs/flutter-apk/app-release.apk
```

বিস্তারিত চেকলিস্ট + iOS: `moneybag_flutter/DEPLOY.md`

> **কিছুই না বসালেও অ্যাপ ১০০% কাজ করে** (অফলাইন-ফার্স্ট) — শুধু পুশ/লগইন/অ্যাড/ড্রাইভ-সিঙ্ক বন্ধ থাকে।

## ৪. সব চালু করার পরে টেস্ট

1. অ্যাপে Google লগইন → ড্যাশবোর্ডের **Users** ট্যাবে নিজের ইমেইল দেখুন
2. Users → **Send Notification** → ফোনে ৩–৫ সেকেন্ডে পুশ
3. **Global Push** → সবাইকে (৪০ জন করে ব্যাচে — অটো)
4. **Announcements** বানান (এখন সময়সীমাও দেওয়া যায়) → অ্যাপের হোমে নোটিশ কার্ড আসবে
5. **Ads & Config** → ads ON → ব্যানার/রিওয়ার্ডেড অ্যাড দেখাবে
6. Worker-এর `/health?deep=1` দিয়ে ডেটাবেস-সহ হেলথ চেক করুন

---

## এই প্যাকেজটা যাচাই করা হয়েছে যেভাবে (২০২6-09-13)

- Worker: TypeScript কম্পাইল PASS (0 errors) + **৩৭টা ভ্যালিডেশন/ইউনিট টেস্ট PASS** (vitest)
- লাইভ প্রোডাকশন API (`moneybag-api.salman61902.workers.dev`) প্রোব করে পুরো route surface ম্যাপ করা হয়েছে — v2 সেই কন্ট্র্যাক্টের সাথে ১০০% ব্যাকওয়ার্ড-কম্প্যাটিবল
- Admin: প্রোডাকশন বিল্ট ক্লিন (vite build PASS, dist ফ্রেশ) + CSP/security headers
- অ্যাপ: ৫১+ Dart ফাইলের ফুল স্ট্যাটিক ভেরিফিকেশন; এই রাউন্ডে বদলানো ১৮টা ফাইল আবার যাচাই
- অ্যাপ ↔ Worker সব API কলের ফরম্যাট দুই দিক মিলিয়ে চেক করা
