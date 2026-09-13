# MoneyBag Admin Dashboard — Cloudflare Pages (React + Tailwind)

Cloudflare Pages-এ হোস্ট হওয়া SPA অ্যাডমিন প্যানেল। Worker API-কে `x-api-key`
দিয়ে কল করে।

## মডিউল

- **Login** — Worker URL + Admin API Key (localStorage-এ থাকে)
- **Dashboard** — ইউজার/পুশ/নোটিশের overview, recent push log (৩০ সেকেন্ডে auto-refresh)
- **Users** — সব রেজিস্টার্ড ইউজার (নাম, ইমেইল, প্লাটফর্ম, শেষ লগইন) + সার্চ +
  প্রতি ইউজারের পাশে **Send Notification** বাটন (টার্গেটেড FCM পুশ)
- **Global Push** — সবাইকে একসাথে (৪০ জন করে ব্যাচে, অটো-পেজিং + প্রগ্রেস বার)
- **Ads & Config** — AdMob on/off + banner/interstitial/**rewarded** unit IDs,
  maintenance mode, force update, min version
- **Announcements** — তৈরি/লুকানো/ডিলিট

## দুইভাবে চালানো যায়

### A) লোকাল ডেভেলপমেন্ট

```bash
cd admin
npm install
npm run dev        # http://localhost:5173
```

### B) Cloudflare Pages-এ ডিপ্লয় (রেকমেন্ডেড)

```bash
cd admin
npm install
npm run build                          # dist/ তৈরি হবে
npx wrangler pages deploy dist --project-name moneybag-admin
# প্রথমবার নাম জিজ্ঞেস করলে "Create a new project" বেছে নাও
```

ডিপ্লয় শেষে যে URL পাবে (যেমন `https://moneybag-admin.pages.dev`) — সেটা ব্রাউজারে
খুলে:
1. **Worker API URL** = `https://moneybag-api.your-name.workers.dev`
2. **Admin API Key** = `ADMIN_API_KEY` সিক্রেটে যা বসিয়েছ
3. Sign in

> GitHub দিয়ে Pages কানেক্ট করতে চাইলে: repo-তে push করো → Cloudflare
> dashboard → Workers & Pages → Create → Pages → Connect to Git → build
> command `npm run build`, output directory `dist`।

বিল্ড যাচাই: `npm run build` ক্লিন হলেই রেডি — আর কোনো সেটআপ নেই।
