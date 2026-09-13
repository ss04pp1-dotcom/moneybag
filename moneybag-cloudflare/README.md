# MoneyBag Cloudflare Stack

MoneyBag-এর পুরো ব্যাকএন্ড এখন Cloudflare-তে (Node.js সার্ভার আর লাগবে না):

```
moneybag-cloudflare/
├── worker/    → Cloudflare Worker API (Hono.js + D1)      → README.md দেখুন
└── admin/     → Cloudflare Pages অ্যাডমিন ড্যাশবোর্ড (React + Tailwind)
```

## দ্রুত সারসংক্ষেপ

1. **Worker ডিপ্লয়** — `worker/README.md`-এর ৫ ধাপ (D1 তৈরি → schema.sql → ২টা সিক্রেট → deploy)
2. **ড্যাশবোর্ড ডিপ্লয়** — `admin/README.md` (`npm run build` → `wrangler pages deploy dist`)।
   `admin/dist` আগেই বিল্ড করা আছে — চাইলে সরাসরি deploy করা যায়।
3. Worker URL → **Flutter অ্যাপের** `lib/core/config.dart` → `adminApiBaseUrl`-এ বসান
   (অ্যাপের সম্পূর্ণ চেকলিস্ট: `moneybag_flutter/DEPLOY.md`)।

## যা যা কন্ট্রোল করা যায়

- App Config — maintenance / force-update / min version
- Ads — on/off + banner / interstitial / **rewarded** unit IDs (রিমোট)
- Announcements — অ্যাপের ড্যাশবোর্ডে নোটিশ
- **Users** — Google সাইন-ইন করা সবাই (নাম, ইমেইল, প্লাটফর্ম, FCM টোকেন)
- **Targeted Push** — নির্দিষ্ট ইউজারকে একা নোটিফিকেশন
- **Global Push** — সবাইকে (৪০/ব্যাচ অটো-পেজিং, ফ্রি প্লান সেফ)

সব ডেটা Cloudflare D1 (SQL)-এ স্থায়ীভাবে থাকে — ফ্রি প্লানেই পুরো স্ট্যাক চলে।
