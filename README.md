# تقويم (Taqweem)

**العربية** | [English](#english)

تطبيق Flutter (واجهة عربية بالكامل، من اليمين إلى اليسار) لإعداد ملصق تقويم شهري
لأهل البيت (ع) وتصديره صورة PNG أو ملف PDF للطباعة والنشر.

## المزايا

- **الرئيسية:** مسودّات محفوظة تلقائياً، نسخ المسودّة إلى الشهر التالي، حذف، ومثال جاهز.
- **محرّر من 4 خطوات:**
  1. إعداد الشهر (السنة والشهر الهجري، تاريخ البداية الميلادي/الشمسي، أوقات الصلاة).
  2. جدول الأيام: اقتراحات مناسبات شيعية لكل يوم، وزر **تعبئة تلقائية** يملأ الملاحظات
     الفارغة فقط بالمناسبات الرئيسية الموثّقة (`verified`).
  3. النصوص (العنوان، الأحاديث، الأسئلة والأجوبة، المقال الختامي، التذييل).
  4. اختيار القالب (10 قوالب) والتصدير PNG/PDF بدقة ×2 / ×3 / ×4.
- **قواعد المحتوى:** المحتوى من مصادر شيعية اثني عشرية فقط، والأوقات تُدخَل يدوياً.

## التشغيل

```bash
flutter pub get
flutter run -d linux        # أو: flutter run -d android
flutter analyze
flutter test
```

صور الاختبار الذهبية (goldens): `flutter test --update-goldens <ملف الاختبار>` **فقط للقوالب
التي غيّرتها**، ثم راجع الصور بالعين قبل اعتمادها.

## بيانات المناسبات الشيعية

المسار الوحيد للتوليد (لا تعدّل `lib/data/shia_occasions.dart` يدوياً أبداً):

- `docs/shia-occasions/research/` — نتائج البحث مع المصادر لكل مناسبة.
- `docs/shia-occasions/convention.json` — اصطلاح تقويم المستخدم: أي تاريخ يكون **رئيسياً** وأيها
  بدائل (`swaps`)، المناسبات الموجودة في التقويم فقط (`scanOnly`)، إصلاحات العناوين والملاحظات، الاستبعادات.
- `docs/shia-occasions/user-calendar-scans.json` — نص تقويم المستخدم حرفياً (مصدر شيعي من الدرجة الأولى).
- `tool/gen_shia_occasions.py` — المولّد؛ شغّله: `python3 -I tool/gen_shia_occasions.py`
  فينتج `lib/data/shia_occasions.dart` و`docs/shia-occasions/DATA-SUMMARY.md`.
  قائمة المنع (`DENYLIST`) تُسقط الأسماء غير المقبولة؛ استثناء واحد: عنوان فيه «صلح» مع «معاوية»
  (صلح الإمام الحسن (ع)) يبقى.
- **معنى `verified`:** المناسبة مذكورة في عائلتين مستقلتين على الأقل من المصادر، وإحداهما ليست
  منتدى العتبة العباسية (alkafeel.net). غير الموثّقة تظهر بعلامة تحذير ولا تدخل التعبئة التلقائية.
  التوثيق ما زال يحتاج مراجعة مع حقيبة المؤمن/مفاتيح الجنان.
- **قاعدة اصطلاح التقويم:** عند اختلاف المصادر الشيعية يتبع التاريخ **الرئيسي** تقويم المستخدم
  (تقويم أهل البيت - المرجع)، وتبقى الأقوال الأخرى بدائل بعبارة «على قول/على رواية».

## القوالب والشعارات

- مجموعة بناء القوالب: [`docs/design/template-kit.md`](docs/design/template-kit.md).
- أصول الشعارات: [`docs/design/logo-assets.md`](docs/design/logo-assets.md). **تنبيه:** الشعارات
  نقطية بعرض 575–860 بكسل فقط، فتبدو ناعمة عند التصدير ×3 أو ×4 أو A3. يُوصى بشعار
  متجهي (SVG) أو عالي الدقة (2000 بكسل فأكثر) للطباعة.

## حدود معروفة

- تصدير ×4 يعطي 4000×8800 بكسل وقد يتجاوز حدّ نسيج GPU في بعض أجهزة أندرويد؛ استخدم ×3 أو ×2.
- لا يوجد تحويل هجري/ميلادي: التواريخ يدخلها المستخدم.
- أوقات الصلاة تُكتب يدوياً ولا تُحسب.

---

## English

Taqweem is a Flutter app (Arabic-only, RTL UI) that builds a monthly Ahl al-Bayt calendar
poster and exports it as PNG or PDF for print and sharing. Content comes from **Twelver Shia
sources only**.

### Features

- **Home:** auto-saved drafts, duplicate as next month, delete, a ready-made sample.
- **4-step editor:**
  1. Month setup (Hijri year/month, Gregorian/solar start date, prayer-time rows).
  2. Day grid: Shia occasion suggestions per day, plus an **auto-fill** button that fills only
     *empty* notes with *verified main* occasions.
  3. Texts (title, quotes, Q&A strips, closing article, footer).
  4. Template picker (10 templates) and PNG/PDF export at x2 / x3 / x4.

### Run

```bash
flutter pub get
flutter run -d linux        # or: flutter run -d android
flutter analyze
flutter test
```

Goldens: `flutter test --update-goldens <test file>` only for the templates you changed, and
review the images before accepting them.

### Shia occasions data pipeline

Single generation path; **never edit `lib/data/shia_occasions.dart` by hand**.

```
docs/shia-occasions/research/*.json  +  convention.json  +  user-calendar-scans.json
        --python3 -I tool/gen_shia_occasions.py-->
lib/data/shia_occasions.dart  +  docs/shia-occasions/DATA-SUMMARY.md
```

- `verified` = cited by at least 2 distinct source families, at least one of which is not the
  weak family alkafeel.net (shrine-forum reposts). Unverified items show a warning mark in the
  grid and are never auto-filled. This is still to be cross-checked against Haqibat al-Mu'min /
  Mafatih al-Jinan.
- Calendar convention rule: where Shia sources disagree, the **main** date follows the user's own
  calendar scans («تقويم أهل البيت»); the other dates stay as alternates marked
  «على قول / على رواية».
- Denylist: titles containing denied names are dropped; the only exception is a title that also
  contains «صلح» together with «معاوية» (Imam al-Hasan's peace treaty).

### Templates and logos

- Template kit: [`docs/design/template-kit.md`](docs/design/template-kit.md).
- Logo assets: [`docs/design/logo-assets.md`](docs/design/logo-assets.md). **Limitation:** the raster
  logos are only 575-860 px wide, so they look soft at x3/x4/A3 export. A vector (SVG) or
  >= 2000 px logo is recommended for print.

### Known limits

- The x4 export is 4000x8800 px and may exceed the GPU max texture size on some Android devices;
  use x3 or x2.
- No Hijri conversion: dates are entered by the user.
- Prayer times are typed in, not calculated.
