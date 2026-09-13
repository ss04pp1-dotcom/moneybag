# MoneyBag v2.0.3 — প্রোডাকশন চেকলিস্ট (কোথায় কী বসাবেন)

নতুন যা যা চালু হবে: **Cloudflare Worker API (Hono.js + D1)** + **Cloudflare Pages অ্যাডমিন ড্যাশবোর্ড (React + Tailwind)** + **রিয়েল-টাইম FCM পুশ** + **অটো Google Drive সিঙ্ক** + **রিওয়ার্ডেড অ্যাড**। অ্যাপে API URL **শুধু কোড থেকেই** বসে (অ্যাপের ভেতরে API সেট করার কোনো অপশন নেই — ডিজাইনেই বাদ)।

---

## ১. Cloudflare Worker ডিপ্লয় (মোট ৫ কমান্ড)

```bash
cd moneybag-cloudflare/worker
npm install
npx wrangler login                        # ব্রাউজারে Cloudflare অ্যাকাউন্ট

npx wrangler d1 create moneybag-db
#   → প্রিন্ট হওয়া database_id কপি করুন

npx wrangler d1 execute moneybag-db --remote --file=schema.sql

npx wrangler secret put ADMIN_API_KEY        # নিজের লম্বা র‍্যান্ডম কী (ড্যাশবোর্ড লগইন)
npx wrangler secret put FCM_SERVICE_ACCOUNT  # Firebase service-account JSON (এক লাইনে)
npx wrangler deploy
```

`database_id` বসানোর জায়গা: **`moneybag-cloudflare/worker/wrangler.toml` → ১১ নম্বর লাইন** (`REPLACE_WITH_YOUR_D1_DATABASE_ID`)।

`FCM_SERVICE_ACCOUNT` পাওয়ার জায়গা: Firebase Console → Project settings → **Service accounts** → *Generate new private key* → ফাইলের পুরো JSON কপি।

ডিপ্লয়ের শেষে যে URL পাবেন (যেমন `https://moneybag-api.your-name.workers.dev`) — **পরের স্টেপে লাগবে**।

## ২. অ্যাডমিন ড্যাশবোর্ড (Cloudflare Pages)

```bash
cd moneybag-cloudflare/admin
npm install && npm run build
npx wrangler pages deploy dist --project-name moneybag-admin
```

ব্রাউজারে খুলে → **Worker API URL** + **Admin API Key** দিয়ে সাইন-ইন।
মডিউল: Dashboard · **Users (প্রতি ইউজারে Send Notification)** · Global Push · Ads & Config (banner/interstitial/**rewarded**) · Announcements।

## ৩. অ্যাপে হার্ডকোড — ৪টা জিনিস, ৪টা লাইন

| # | কী | ফাইল : লাইন | কী বসাবেন |
|---|---|---|---|
| 1 | **Google Web Client ID** | `lib/core/config.dart` → **লাইন ২১-২২** (`googleWebClientId`) | `PASTE_YOUR_WEB_CLIENT_ID.apps.googleusercontent.com` এর জায়গায় আপনার Web OAuth Client ID (Google Cloud Console → Credentials → Web application; Android SHA-1 যোগ করা থাকতে হবে)। এটাই Google লগইন + Drive অটো-সিঙ্ক চালু করে |
| 2 | **Cloudflare Worker API URL** | `lib/core/config.dart` → **লাইন ৪১-৪২** (`adminApiBaseUrl`) | `https://moneybag-api.YOUR-SUBDOMAIN.workers.dev` এর জায়গায় ১-এ পাওয়া আসল URL। অ্যাপের **সব** API কল (কনফিগ/অ্যাড/নোটিশ/ইউজার-সিঙ্ক/পুশ রেজিস্ট্রেশন) এই একটাই দিয়ে চলে |
| 3 | **google-services.json** (Android) | `android/app/google-services.json` | প্লেসহোল্ডার ফাইলটা Firebase থেকে ডাউনলোড করা **আসল** ফাইল দিয়ে রিপ্লেস (Firebase → Project settings → Android app, প্যাকেজ `bd.moneybag.moneybag`) → FCM পুশ চালু |
| 3b | **GoogleService-Info.plist** (iOS) | `ios/Runner/GoogleService-Info.plist` | iOS অ্যাপ যোগ করে আসল plist বসান (Push capability + APNs সেটআপ Xcode-এ) |
| 4 | **AdMob App ID** | Android: `android/app/src/main/AndroidManifest.xml` → **লাইন ২১** · iOS: `ios/Runner/Info.plist` → **লাইন ২৮** | এখন দুটোই Google-এর টেস্ট ID। আসল AdMob App ID (`ca-app-pub-XXXX~YYYY`) বসিয়ে একবার রিবিল্ড। Unit ID গুলো অ্যাডমিন প্যানেল থেকে রিমোটলি বদলানো যায় |

> সব বসানোর পর **একবার রিবিল্ড**: `flutter build apk --release` (বা `flutter build ipa`)।
> কিছুই না বসালেও অ্যাপ ১০০% কাজ করে (অফলাইন-ফার্স্ট) — শুধু পুশ/লগইন/অ্যাড/ড্রাইভ বন্ধ থাকে।

## ৪. রিওয়ার্ডেড অ্যাড ও অ্যাড কন্ট্রোল

- অ্যাডমিন ড্যাশবোর্ড → **Ads & Config** → `Ads enabled` ON → rewarded/banner/interstitial unit ID বসান → Save।
- `Test mode` ON থাকলে Google-এর নিরাপদ টেস্ট অ্যাড দেখায় — আসল ID বসানোর পর OFF করুন।
- ইউজার রিওয়ার্ড অ্যাড দেখলে **২৪ ঘণ্টা বিজ্ঞাপনমুক্ত** থাকে (প্রোফাইল → সাপোর্ট কার্ড)।

## ৫. FCM + ইউজার ম্যানেজমেন্ট ফ্লো (কীভাবে কাজ করে)

1. ইউজার অ্যাপে **Google দিয়ে সাইন-ইন** করল → অ্যাপ নাম-ইমেইল-UID + FCM টোকেন `POST /api/users/sync`-এ পাঠায় (guest হলে device-id)।
2. ড্যাশবোর্ডের **Users** ট্যাবে ইউজার দেখা যায় → নির্দিষ্ট ইউজারকে **Send Notification**।
3. **Global Push** → সবাইকে (৪০ জন করে ব্যাচে, অটো-পেজিং — ফ্রি প্লানেই চলে)।
4. অ্যাপে ফোরগ্রাউন্ড মেসেজ সাথে সাথে নোটিফিকেশন হয়ে দেখায়, ব্যাকগ্রাউন্ডে সিস্টেম ট্রে-তে; নোটিশ/অ্যাড কনফিগ তখনই রিফ্রেশ হয়।

## ৬. অটো Drive সিঙ্ক

- লগইনের পর ডিভাইস খালি থাকলে + Drive-এ ব্যাকআপ থাকলে → **নিজে থেকেই ডাউনলোড → ডিক্রিপ্ট → রিস্টোর** (পাসফ্রেজ জানা থাকলে একটাপও লাগে না; নতুন ডিভাইসে একবার পাসফ্রেজ চায়)।
- প্রতিটা সেভ/ডিলিটের **৫ সেকেন্ড** পর এনক্রিপ্টেড ব্যাকআপ নিজে থেকেই Drive-এ যায় (৬০ সেকেন্ডে সর্বোচ্চ ১ বার; অ্যাপ বন্ধ করলে সাথে সাথে আপলোড)।
- চাইলে Backup স্ক্রিনের Drive ট্যাবে **অটো সিঙ্ক** টগল দিয়ে বন্ধ করা যায়।

## ৭. রিমাইন্ডার ফিক্স (v2)

- সময় ধরে নির্ভুল করতে এখন **alarmClock মোড** (স্টক ক্লক অ্যাপের মেকানিজম — Walton/Symphony/MIUI-জাতীয় ROM-এর ব্যাটারি সেভারও এটা কখনো বন্ধ করে না), তারপর exact → inexact ফলব্যাক।
- টাইমজোন এখন `flutter_timezone` দিয়ে আসল IANA নামে (`Asia/Dhaka`) — আগে Android-এ ভুল নাম পেয়ে শিডিউল নীরবে ফেইল করত।
- রিমাইন্ডার মিস হলে (ফোন বন্ধ ছিল ইত্যাদি) অ্যাপ খুললেই catch-up নোটিফিকেশন।
- নোটিফিকেশন সেন্টারে এখন আসল স্ট্যাটাস: কোন মোডে শিডিউল হলো, OS-এ কয়টা অ্যালার্ম আছে, ব্যর্থ হলে **প্লেইন টেক্সটে** এরর (v1.3-এর "Closure: PlatformException" লিক বাগ সম্পূর্ণ সরানো)।

## ৮. দ্রুত টেস্ট (সবকিছু চালু করার পর)

1. অ্যাপে Google লগইন → ড্যাশবোর্ডে Users-এ নিজের ইমেইল দেখুন।
2. Users → Send Notification → ফোনে ৩-৫ সেকেন্ডে পুশ আসে (অ্যাপ খোলা থাকলেও)।
3. একটা খরচ সেভ করুন → ৫-৬ সেকেন্ড পর Drive-এ `moneybag-auto-latest.mbbak` আপডেট হয়।
4. নোটিফিকেশন স্ক্রিনে OS-এ নিশ্চিত রিমাইন্ডার: **২টি** দেখার কথা (daily + weekly)।
5. Ads enabled করে প্রোফাইল → সাপোর্ট → রিওয়ার্ড অ্যাড দেখুন → ২৪ ঘণ্টা ব্যানার বন্ধ।

## ৯. v2.1 স্মার্ট ফিচার — ডিপ্লয় নোট

- **কোনো নতুন API কী লাগে না** — OCR (ML Kit) সম্পূর্ণ অন-ডিভাইস ও অফলাইন,
  ফিঙ্গারপ্রিন্ট লক লোকাল, উইজেট ও Material You নিখাদ ক্লায়েন্ট-সাইড।
- **নতুন পারমিশন**: `USE_BIOMETRIC` (ফিঙ্গারপ্রিন্ট লকের জন্য) — Android
  নিজেই ইউজারকে জিজ্ঞেস করে দেয়, আলাদা ডায়ালগ লাগে না।
- **MainActivity** এখন `FlutterFragmentActivity` (local_auth-এর রিকোয়ারমেন্ট) —
  Flutter-এর জন্য আচরণ অভিন্ন।
- **হোম উইজেট**: লঞ্চারের উইজেট পিকারে "মানিব্যাগ" — ডেটা প্রতিটি সেভ/ডিলিটের
  পর অটো-পুশ হয় (`MbWidgetSyncService`)। iOS উইজেট এক্সটেনশন যোগ করা হয়নি —
  Dart সাইড Android-এ কন্ট্রোল করা।
- APK সাইজ বাড়বে (~৪৫-৫০MB) — ML Kit টেক্সট-রিকগনিশন মডেল বান্ডেল থাকার কারণে।
  চাইলে `google_mlkit_text_recognition` সরিয়ে দিলে ওই অংশটা বেঁচে যায়।

বিল্ড যাচাই: `flutter analyze` **0 issues** · APK `bd.moneybag.moneybag v2.1.0+10` (minSdk 21, targetSdk 34)।
