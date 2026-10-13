# مقارنة تقويم المستخدم بقاعدة البيانات / Scans vs DB (S6a, 2026-10-13)

Sources: `docs/shia-occasions/user-calendar-scans.json` (5 real scans of «تقويم أهل البيت», transcribed verbatim; Gemini mock-ups ignored) vs `lib/data/shia_occasions.dart` (117 entries; months 1,2,3,5 compared). Notes were split on « - » into parts (2 joined parts split on «هـ و» / «هـ اكتشاف»). Jumada I appears in two scans (1446 and 1448) with the same notes per Hijri day, so month-5 items usually have 2 occurrences.

Matching is by meaning (same figure + same event), not text. User convention (R24): the scans define which date is MAIN; DB entries that differ become alternates.

## (A) مطابق لقاعدة البيانات / Matches the DB

| month/day | scan text (verbatim) | scans | DB entry |
|---|---|---|---|
| 1/1 | رأس السنة الهجرية1446هـ | محرم 1446 | 1/1 غرة محرم - رأس السنة الهجرية |
| 1/2 | وصول الإمام الحسين(ع)لأرض كربلاء | محرم 1446 | 1/2 وصول الإمام الحسين (ع) وأصحابه إلى كربلاء |
| 1/6 | غداً بأمرعمر بن سعد جيشه لحراسة نهر العلقمي لمنع وصول الحسين(ع) وعياله | محرم 1446 | 1/7 منع الماء ... (scan says «غداً» on the 6th, i.e. the event is on the 7th) |
| 1/7 | منع الماء عن أهل البيت(ع) | محرم 1446 | 1/7 منع الماء عن الإمام الحسين (ع) ... |
| 1/9 | يوم التاسوعا | محرم 1446 | 1/9 تاسوعاء |
| 1/10 | ذكرى استشهاد الإمام الحسين (ع) وأصحابه(ع)61هـ | محرم 1446 | 1/10 يوم عاشوراء |
| 1/11 | نقل سبايا أهل البيت(ع)الى الكوفه | محرم 1446 | 1/11 سَوق أهل بيت الإمام الحسين (ع) سبايا نحو الكوفة |
| 1/19 | نقل سبايا آل الرسول(ع)من الكوفة الى الشام | محرم 1446 | 1/19 انتقال قافلة سبايا أهل البيت (ع) من الكوفة إلى الشام |
| 1/25 | استشهاد الإمام زين العابدين(ع)94هـ | محرم 1446 | 1/25 ذكرى استشهاد الإمام زين العابدين (ع) |
| 2/1 | معركة صفين37هـ | صفر 1448 | 2/1 واقعة صفين |
| 2/1 | وصول رأس الحسين(ع)وسبايا آل البيت(ع)للشام | صفر 1448 | 2/1 دخول سبايا آل محمد (ع) ورؤوس الشهداء إلى الشام |
| 2/5 | ذكرى وفاة السيدة رقية بنت الإمام الحسين (ع) 61هـ | صفر 1448 | 2/5 استشهاد السيدة رقية (ع) |
| 2/7 | ومولد الإمام الكاظم (ع)128هـ | صفر 1448 | 2/7 مولد الإمام الكاظم (ع) |
| 2/8 | وفاة سلمان الفارسي(رض)35هـ | صفر 1448 | 2/8 وفاة سلمان المحمدي (رض) |
| 2/9 | واقعة النهروان38هـ | صفر 1448 | 2/9 معركة النهروان |
| 2/9 | وفاة عمار بن ياسر37هـ | صفر 1448 | 2/9 استشهاد عمار بن ياسر (رض) في صفين |
| 2/20 | ذكرى أربعينية الإمام الحسين(ع)وشهداء الطف(ع) | صفر 1448 | 2/20 أربعينية الإمام الحسين (ع) |
| 2/28 | ذكرى استشهاد النبي الأكرم(ص)11هـ | صفر 1448 | 2/28 وفاة النبي الأكرم محمد (ص) |
| 3/1 | الهجرة النبوية من مكة الى المدينة ومبيت الإمام علي(ع) على فراش النبي(ص) | ربيع الأول 1448 | 3/1 ليلة المبيت + هجرة النبي (ص) |
| 3/5 | ذكرى وفاة السيدة سكينة بنت الإمام الحسين (ع) 117هـ | ربيع الأول 1448 | 3/5 وفاة السيدة سكينة (ع) |
| 3/8 | ذكرى إستشهاد الإمام الحسن العسكري (ع) 260هـ | ربيع الأول 1448 | 3/8 استشهاد الإمام العسكري (ع) |
| 3/9 | أول أيام إمامة الحجّة بن الحسن(ع) | ربيع الأول 1448 | 3/9 بداية إمامة الإمام المهدي (عج) (DB main, verified: false - the scan supports it; DB also has 3/8 alternate) |
| 3/10 | زواج الرسول من خديجة15ق هـ | ربيع الأول 1448 | 3/10 زواج النبي (ص) من السيدة خديجة (س) |
| 3/17 | مولدالرسول الأعظم(ص) وحفيده الإمام الصادق(ع)83هـ | ربيع الأول 1448 | 3/17 مولد النبي (ص) + 3/17 مولد الإمام الصادق (ع) |
| 5/5 | مولد السيدة زينب الكبرى(ع) | جمادى الأولى 1446, جمادى الأولى 1448 | 5/5 ولادة السيدة زينب الكبرى (س) |
| 5/10 | حرب الجمل 36هـ | جمادى الأولى 1446, جمادى الأولى 1448 | 5/10 وقعة الجمل |
| 5/15 | فتح البصرة على يدالإمام علي بن أبي طالب(ع) | جمادى الأولى 1446, جمادى الأولى 1448 | 5/15 دخول أمير المؤمنين (ع) البصرة بعد انتصاره في حرب الجمل |

## (B) تعارض مع قاعدة البيانات / Conflicts with the DB (key output)

| # | event | scan (main per user convention) | DB now | matching reasoning | recommendation |
|---|---|---|---|---|---|
| B1 | استشهاد الإمام الحسن المجتبى (ع) | **7 صفر** (highlighted, «ذكرى استشهاد الإمام المجتبى (ع)50هـ», Safar 1448) | main **28 صفر** («استشهاد الإمام الحسن المجتبى (ع)»); alt 7 صفر «على رواية» | same Imam, same event (martyrdom, 50 AH); scan 28 Safar row has only the Prophet | **Swap**: 7 Safar → main; 28 Safar → alternate («على رواية»/«على قول»). |
| B2 | استشهاد الإمام علي بن موسى الرضا (ع) | **17 صفر** (highlighted, «...203هـ») | main **30 صفر** («- آخر صفر»); alt 17 صفر «على رواية (أخرى)»; alt 23 ذي القعدة (unverified) | same Imam/event; scan 30 Safar has no Ridha note | **Swap**: 17 Safar → main; 30 Safar → alternate; keep 23 Dhu al-Qa'da as alternate (unverified). |
| B3 | استشهاد السيدة فاطمة الزهراء (س) | **13 جمادى الأولى** (highlighted in both Jumada I scans, «ذكرى استشهاد سيدة نساء العالمين فاطمة الزهراء(ع)11هـ») | main **3 جمادى الآخرة**; alt 13 جمادى الأولى (75-day narration); alt 8 ربيع الآخر (40-day) | same person/event (11 AH); Jumada II not scanned, so we cannot see whether the user's calendar also marks 3 Jumada II | **Swap**: 13 Jumada I → main; 3 Jumada II → alternate («على رواية 95 يوماً», commemorated as الفاطمية الثانية); keep 8 Rabi II alternate. Ask the user if 3 Jumada II should stay prominent. |
| B4 | مولد النبي الأكرم (ص) | 17 ربيع الأول main (highlighted «مولدالرسول الأعظم(ص) وحفيده الإمام الصادق(ع)83هـ») **and** 12 ربيع الأول highlighted «مولد النبي محمد(ص)على رواية» | main 17 ربيع الأول only; **no 12 Rabi I alternate** (research put 12th in "unconfirmed" as WikiShia ascribes it to Sunnis) | same event; scan itself labels 12th «على رواية» | Keep 17 main (matches). **Add 12 Rabi I as alternate** «على رواية» (scan is a Shia source; it is also the Kulayni view). |
| B5 | وفاة محمد بن عثمان العمري (رض) السفير الثاني | **28 جمادى الأولى** («وفاة السفير الثاني محمد بن عثمان304هـ», both Jumada I scans) | main **29 جمادى الأولى** | same person (2nd safir), same year 304 | Swap: 28 → main; 29 → alternate «على قول». |
| B6 | وفاة عبد المطلب جد النبي (ص) | **10 ربيع الأول** («وفاة عبدالمطلب بن هاشم جد الرسول(ص)») | main **27 جمادى الأولى** (scan 27 Jumada I has only the minarets bombing) | same person/event; research had 10 Rabi I from WikiShia + alkafeel (unconfirmed only due to an 8th-day conflict) | Swap: 10 Rabi I → main; 27 Jumada I → alternate «على قول». |
| B7 | وصول النبي (ص) إلى المدينة (قباء) | 11 ربيع الأول «وصول الرسول لأرض يثرب واعلان الدولة الأسلامية»; also 2 صفر «نزول النبي(ص) بقباء» | main 12 ربيع الأول «وصول النبي الأكرم (ص) إلى المدينة المنورة (قباء) مهاجراً» | same Hijra arrival. The 2 Safar item is chronologically inconsistent with the scan's own Hijra on 1 Rabi I (likely a different/erroneous tradition); 11 vs 12 Rabi I is a 1-day difference (Quba vs Yathrib?) | User decides. Suggested: keep DB 12 Rabi I; add 11 Rabi I as alternate only if the user wants; do **not** adopt 2 Safar. |
| B8 | بدء نزول الوحي / المبعث | 2 جمادى الأولى «بدأ نزول الوحي على النبي محمد(ص)» (both Jumada I scans; not highlighted) | Mab'ath 27 رجب (main) | possibly the same event (beginning of revelation) under a minority tradition, or a distinct "first revelation" item | Keep 27 Rajab main (Shia consensus). Optionally add 2 Jumada I as a separate entry «بدء نزول الوحي (على رواية)» – user decides. |

DB entries in these months that the scans do NOT show (for information, no action implied): 1/9 part «حصار مخيم»; 2/20 «عودة أهل بيت الإمام الحسين (ع) إلى كربلاء»; 3/8 alt «بداية إمامة المهدي»; 3/12 (see B7); 5/15 alt «ولادة الإمام زين العابدين (ع) على رواية»; 5/27 (see B6); 5/29 (see B5).

## (C) موجود في التقويم وغير موجود في قاعدة البيانات / In the scans, MISSING from the DB (candidates to add)

| month/day | scan text (verbatim) | scans | note |
|---|---|---|---|
| 1/1 | وفاة محمد بن الحنفية | محرم 1446 | son of Imam Ali (Ahl al-Bayt family); no year printed; check that Twelver calendars commemorate it (research did not cover it). |
| 1/3 | وصول عمر بن سعد وجيشة لأرض كربلاء | محرم 1446 | Karbala event; research had it "unconfirmed" (3 Muharram, alkafeel only) - the scan is a 2nd source. |
| 1/4 | فتوى شريح القاضي بقتل الامام الحسين(ع) | محرم 1446 (highlighted) | Karbala-related; **highlighted** in the scan. |
| 1/12 | دفن الأجساد الطاهرة لشهداء الطف بأرض كربلاء | محرم 1446 | Karbala; research had 13 Muharram (alkafeel only); the scan says **12** - use 12 as main per convention, 13 as alternate. |
| 1/15 | قدوم جعفر بن ابي طالب الى الحبشة | محرم 1446 | Ja'far al-Tayyar (Ahl al-Bayt family) - migration to Abyssinia. |
| 2/14 | شهادة محمد بن أبي بكر(رض)في مصر38هـ | صفر 1448 | companion/governor of Imam Ali; research: 14 Safar (alkafeel) and 15 Jumada I (another alkafeel list) - scan says 14 Safar. |
| 2/18 | شهادة أويس القرني(رض)في صفين | صفر 1448 | companion of Imam Ali, martyred at Siffin. |
| 2/19 | وصول جابر الأنصاري(رض)الى كربلاء61هـ | صفر 1448 | research had Jabir's visit on 20 Safar (WikiShia only); scan puts his arrival at Karbala on **19** Safar (20 = Arbaeen). |
| 2/26 | إستشهاد أولاد مسلم بن عقيل(ع)61هـ | صفر 1448 | Ahl al-Bayt family, Karbala aftermath (61 AH). |
| 2/28 | وغداً إسقاط الزهراء(ع) لمحسن | صفر 1448 (highlighted) | printed on 28 Safar as «وغداً ...» → the event is on **29 Safar**; Fatima (s). |
| 3/1 | دفن الرسول الأكرم(ص) | ربيع الأول 1448 | the Prophet (ص); 1 Rabi I. |
| 3/2 | وصول سبايا الامام الحسين(ع)الى المدينة | ربيع الأول 1448 | Karbala aftermath (return of the captives to Medina). |
| 3/6 | زيارة فاطمة الزهراء(س)لقبر ابيها(ص)بعد وفاته | ربيع الأول 1448 | Fatima (s). |
| 3/15 | بناء أول مسجد في الإسلام (مسجد قباء) 1هـ | ربيع الأول 1448 | Prophet (ص); research unconfirmed (alkafeel 15 Rabi I) - scan confirms 15. |
| 3/16 | عروج النبي(ص)الى السماء برواية ابن طاووس | ربيع الأول 1448 | Prophet's Mi'raj «برواية ابن طاووس» → alternate of the 27 Rabi I item below. |
| 3/18 | بناء المسجدالنبوي | ربيع الأول 1448 | Prophet (ص); research unconfirmed (alkafeel 18). |
| 3/22 | غزوة بني النضير4هـ وافراج اليهود من المدينة واعفاء فدك الزهراء(س) | ربيع الأول 1448 | Prophet's battle + Fadak given to al-Zahra (s) (Fadak is in scope); research unconfirmed 22 (alkafeel). |
| 3/26 | صلح الإمام الحسن(ع)مع معاوية بن أبي سفيان41هـ | ربيع الأول 1448 | Imam al-Hasan (ع); research: 26 vs 22 Rabi I conflict - the scan says 26. |
| 3/27 | معراج الرسول(ص) | ربيع الأول 1448 | Prophet's Mi'raj; DB has no Isra/Mi'raj at all → main 27 Rabi I (scan), alt 16 Rabi I. |
| 5/6 | غزوة مؤته8هـ | جمادى الأولى 1446, جمادى الأولى 1448 | battle of Mu'ta = martyrdom of Ja'far al-Tayyar (ع); research conflict (2/5/6/10 Jumada I) - scan says **6** Jumada I. |
| 5/12 | وفاة عبدا... بن عبدالمطلب والد الرسول الأكرم(ص) | جمادى الأولى 1446, جمادى الأولى 1448 | father of the Prophet (ص); research unconfirmed (12 Jumada I, EN WikiShia only) - scan confirms 12. |
| 5/19 | مقتل زيد بن صوحان36هـ | جمادى الأولى 1446, جمادى الأولى 1448 | companion of Imam Ali killed at Jamal (36 AH). The scans list him on **both 19 and 21** Jumada I; research had 19 (alkafeel). Suggest main 19, alt 21 (or ask user). |
| 5/21 | استشهاد الصحابي الجليل زيد بن صوحان | جمادى الأولى 1446, جمادى الأولى 1448 | companion of Imam Ali killed at Jamal (36 AH). The scans list him on **both 19 and 21** Jumada I; research had 19 (alkafeel). Suggest main 19, alt 21 (or ask user). |
| 5/22 | وفاة القاسم ابن الامام موسى الكاظم(ع)192هـ | جمادى الأولى 1446, جمادى الأولى 1448 (highlighted) | son of Imam al-Kazim (ع), **highlighted** in both scans; 22 Jumada I. |

Proposed DB titles must keep the verbatim scan text (or the user's confirmation of a cleaned title); dates above are the scan dates (= main per convention).

## (D) مستبعد / Excluded (scholars, marja', modern martyrs, Sunni/rulers, unrelated history)

| month/day | scan text (verbatim) | scans | reason |
|---|---|---|---|
| 1/13 | رحيل الخطيب الكبيرالدكتورالشيخ احمد الوائلي 2003/7/14م | محرم 1446 | scholar / marja' / modern martyr |
| 1/15 | ولادة ابن طاووس589هـ | محرم 1446 | scholar / marja' / modern martyr |
| 1/20 | غداً بداية الحرب العالمية الاولى1914م | محرم 1446 | modern / non-religious event |
| 1/21 | وفاة الشيخ أبو جعفر محمد بن الحسن الطوسي 460هـ(شيخ الطائفة) | محرم 1446 | scholar / marja' / modern martyr |
| 1/22 | غداً مجزرة قانا الثانية2006م | محرم 1446 | modern / non-religious event |
| 1/23 | وفاة العلامة النراقي 1409هـ | محرم 1446 | scholar / marja' / modern martyr |
| 1/25 | معركة القادسية14هـ | محرم 1446 | Sunni figure / ruler / unrelated history |
| 1/26 | وفاة العالم عبدا... بن الحسين التستري1021هـ | محرم 1446 | scholar / marja' / modern martyr |
| 1/27 | يوم امس استشهاد آية ا...فضل ا...النوري 1909م | محرم 1446 | scholar / marja' / modern martyr |
| 1/28 | سقوط الدولة العباسية 656هـ ومقتل المعتصم وسقوط بغداد بيد المغول | محرم 1446 | Sunni figure / ruler / unrelated history |
| 1/29 | وفاة الشيخ نصير الدين الطوسي 458هـ | محرم 1446 | scholar / marja' / modern martyr |
| 2/8 | وفاة آية ا...المرعشي النجفي1411هـ | صفر 1448 | scholar / marja' / modern martyr |
| 2/9 | وفاة آية ا... الخوئي1413هـ | صفر 1448 | scholar / marja' / modern martyr |
| 2/10 | وفاة العالم ملا جعفر الاسترابادي1263هـ | صفر 1448 | scholar / marja' / modern martyr |
| 2/11 | بعد غد بداية الحرب العالمية الأولى1914/7/28م | صفر 1448 | modern / non-religious event |
| 2/12 | اغتيال السيد محمد تقي الخوئي1415هـ | صفر 1448 | scholar / marja' / modern martyr |
| 2/13 | وفاة احمد بن شعيب النسائي صاحب كتاب السنن303هـ | صفر 1448 | Sunni figure / ruler / unrelated history |
| 2/15 | مجزرة قانا الثانية2006م | صفر 1448 | modern / non-religious event |
| 2/15 | نشوء الدولة الفاطمية في مصر | صفر 1448 | ruler / dynasty (Isma'ili), non-Shia-religious history |
| 2/16 | بعد غد استشهاد آية ا...فضل ا...النوري 1909م | صفر 1448 | scholar / marja' / modern martyr |
| 2/19 | وفاة آية ا...المرعشي النجفي1411هـ | صفر 1448 | scholar / marja' / modern martyr |
| 2/21 | تولي عمر بن عبدالعزيز الخلا فة | صفر 1448 | Sunni figure / ruler / unrelated history |
| 2/22 | سقوط أول قنبلة ذرية امريكية على هيروشيما اليابانية 1945م | صفر 1448 | modern / non-religious event |
| 2/23 | اعلان الدولة العباسية132هـ وانتهاء حكم بني أمية | صفر 1448 | Sunni figure / ruler / unrelated history |
| 2/24 | هزيمة اسرائيل وانسحابة من جنوب لبنان 2006/8/14م | صفر 1448 | modern / non-religious event |
| 2/25 | وفاة سيف الدولة الحمداني356هـ | صفر 1448 | Sunni figure / ruler / unrelated history |
| 2/27 | وفاة آية ا...عبدالأعلى السبزواري1414هـ | صفر 1448 | scholar / marja' / modern martyr |
| 2/29 | وفاة الشيخ محمد امين زين الدين1419هـ | صفر 1448 | scholar / marja' / modern martyr |
| 2/30 | وفاة ميرزااسفند بن قرايوسف848هـ الذي فتح باب المناظرة بين الشيعةوالعامة | صفر 1448 | scholar / marja' / modern martyr |
| 3/2 | رحيل آيةا...عبدالأعلى السبزواري 1993م | ربيع الأول 1448 | scholar / marja' / modern martyr |
| 3/4 | رحيل العلامة الشيخ يوسف البحراني1186هـ ودفن في كربلاء | ربيع الأول 1448 | scholar / marja' / modern martyr |
| 3/7 | ذكرى إحراق المسجد الأقصى على يد الصهاينة 1969م | ربيع الأول 1448 | modern / non-religious event |
| 3/9 | مولد السيد حسن نصرا...1380هـ | ربيع الأول 1448 | scholar / marja' / modern martyr |
| 3/13 | تاسيس دارالتقريب بين المذاهب الإسلامية في القاهرة | ربيع الأول 1448 | modern / non-religious event |
| 3/16 | استشهاد الشهيدان رجائي وباهنر1981م | ربيع الأول 1448 | modern / non-religious event |
| 3/20 | وفاة بشر الحافى227هـ | ربيع الأول 1448 | Sunni figure / ruler / unrelated history |
| 3/21 | استشها آية ا... قدوسى 1981م | ربيع الأول 1448 | scholar / marja' / modern martyr |
| 3/23 | استشهاد السيد حسن نصرا... امين حزب ا... 1446هـ | ربيع الأول 1448 | scholar / marja' / modern martyr |
| 3/24 | وفاة آيةا...سيد محمود طالقاني1979/9/10م | ربيع الأول 1448 | scholar / marja' / modern martyr |
| 3/25 | وفاة العلامة السيد الشريف المرتضى(علم الهدى)438هـ | ربيع الأول 1448 | scholar / marja' / modern martyr |
| 3/27 | وفاة الشيخ النائيني1315هـ | ربيع الأول 1448 | scholar / marja' / modern martyr |
| 3/27 | يوم امس وفاة السيد محسن الحكيم1390هـ | ربيع الأول 1448 | scholar / marja' / modern martyr |
| 5/1 | غداً استشهاد شهيدالمحراب الخامس آية الله اشرف اصفهاني1982م | جمادى الأولى 1448 | scholar / marja' / modern martyr |
| 5/4 | وفاة الشيخ ميثم البحرانى 679هـ | جمادى الأولى 1448 | scholar / marja' / modern martyr |
| 5/4 | وفاة الشيخ ميثم البحراني 679هـ | جمادى الأولى 1446 | scholar / marja' / modern martyr |
| 5/5 | يوم الممرضة المسلمة | جمادى الأولى 1446, جمادى الأولى 1448 | modern / non-religious event |
| 5/7 | استشهاد السيد مصطفى الخميني(ر ض)1977/10/23م | جمادى الأولى 1448 | scholar / marja' / modern martyr |
| 5/7 | بعد غد استشهاد آيةا...قاضي الطباطبائي اول شهيد المحراب1979م | جمادى الأولى 1446 | scholar / marja' / modern martyr |
| 5/8 | وفاة السيد الخونسارى1313هـ | جمادى الأولى 1446 | scholar / marja' / modern martyr |
| 5/8 | وفاة السيد الخونساري1313هـ | جمادى الأولى 1448 | scholar / marja' / modern martyr |
| 5/11 | وفاة المفسر المعروف بالفخر الرازي(رض) | جمادى الأولى 1446, جمادى الأولى 1448 | Sunni figure / ruler / unrelated history |
| 5/12 | استبعادالامام الخميني من ايران الى تركيا1964م | جمادى الأولى 1446 | modern / non-religious event |
| 5/14 | وفاة الدكتوراحمدالوائلي1424هـ | جمادى الأولى 1446, جمادى الأولى 1448 | scholar / marja' / modern martyr |
| 5/16 | اكتشاف اشعة X1895م | جمادى الأولى 1446 | modern / non-religious event |
| 5/19 | غداً استشهاد آيةا...قاضي الطباطبائي اول شهيد المحراب1979م | جمادى الأولى 1448 | scholar / marja' / modern martyr |
| 5/19 | وقف الحرب العالمية الأولى1918م | جمادى الأولى 1446 | modern / non-religious event |
| 5/20 | إستشهاد الشهيد الأول(محمد بن مكي العاملي)786هـ(رض) | جمادى الأولى 1446, جمادى الأولى 1448 | scholar / marja' / modern martyr |
| 5/21 | احراق المسجد الأقصى بيد اليهود69هـ | جمادى الأولى 1446, جمادى الأولى 1448 | modern / non-religious event |
| 5/22 | وفاة الشاعرسيد رضا الهندي1362هـ | جمادى الأولى 1446, جمادى الأولى 1448 | scholar / marja' / modern martyr |
| 5/23 | وفاة الفقيه ابن شاذان 376هـ | جمادى الأولى 1446, جمادى الأولى 1448 | scholar / marja' / modern martyr |
| 5/23 | يوم أمس رحيل آيةا... محمد تقي بهجت 1430هـ | جمادى الأولى 1446, جمادى الأولى 1448 | scholar / marja' / modern martyr |
| 5/24 | وفاة السيد محمد تقي القمي1344هـ | جمادى الأولى 1446, جمادى الأولى 1448 | scholar / marja' / modern martyr |
| 5/24 | يوم امس استبعادالامام الخميني من ايران الى تركيا1964م | جمادى الأولى 1448 | modern / non-religious event |
| 5/25 | وفاة معاوية بن يزيد(الخير)64هـ | جمادى الأولى 1446, جمادى الأولى 1448 | Umayyad ruler (brief explicitly excludes Mu'awiya b. Yazid, even though the scan calls him «الخير») |
| 5/26 | وفاة المحقق النائيني1355هـ | جمادى الأولى 1446, جمادى الأولى 1448 | scholar / marja' / modern martyr |
| 5/28 | استشهاد المجاهد عزالدين القسام1935م | جمادى الأولى 1446 | modern / non-religious event |
| 5/30 | استشهاد شهيدالمحراب الخامس آية الله اشرف اصفهاني1982/11/14م | جمادى الأولى 1446 | scholar / marja' / modern martyr |
| 5/30 | وقف الحرب العالمية الأولى1918م | جمادى الأولى 1448 | modern / non-religious event |

## (E) حالات حدّية لقرار المستخدم / Borderline - user decides

| month/day | scan text (verbatim) | scans | why borderline |
|---|---|---|---|
| 1/1 | غزوة ذات الرقاع4هـ | محرم 1446 | battle of the Prophet; the scans themselves put it on BOTH 1 Muharram and 16 Jumada I |
| 1/3 | خلاص النبي يوسف(ع) من البئر | محرم 1446 | earlier prophets' events (not in the user's include list) |
| 1/5 | عبورالنبي موسى(ع)البحر الأحمر وهلاك فرعون وجنوده | محرم 1446 | earlier prophets' events (not in the user's include list) |
| 1/7 | اليوم الذي تكلم ا... مع نبيه موسى(ع) في جبل طور | محرم 1446 | earlier prophets' events (not in the user's include list) |
| 1/8 | خلاص النبي يوسف(ع)من السجن | محرم 1446 | earlier prophets' events (not in the user's include list) |
| 1/9 | خروج يونس(ع)من بطن الحوت ويُنجيه | محرم 1446 | earlier prophets' events (not in the user's include list) |
| 1/11 | وفاة النبي ادم(ع)عن عمر 930سنة | محرم 1446 | earlier prophets' events (not in the user's include list) |
| 1/17 | هلاك اصحاب الفيل | محرم 1446 | pre-Islamic (Year of the Elephant) |
| 1/19 | مولد النبي عيسى بن مريم المسيح(ع) | محرم 1446 | earlier prophets' events (not in the user's include list) |
| 1/22 | وفاة حواء(س)عن عمر931سنة | محرم 1446 | pre-Islamic prophets/figures (not in the user's include list) |
| 1/23 | خروج زيد بن علي(رض) | محرم 1446 | Zayd b. Ali (son of Imam al-Sajjad): Shia calendars mark him, but dates conflict (1/2/3 Safar) and he is the Zaydi eponym |
| 1/24 | اندلاع ثورة زيد بن علي ضد الأمويين | محرم 1446 | Zayd b. Ali (son of Imam al-Sajjad): Shia calendars mark him, but dates conflict (1/2/3 Safar) and he is the Zaydi eponym |
| 2/2 | استشهاد زيد بن على(رض)121هـ | صفر 1448 | Zayd b. Ali (son of Imam al-Sajjad): Shia calendars mark him, but dates conflict (1/2/3 Safar) and he is the Zaydi eponym |
| 2/3 | احراق مسلم بن عقبة الكعبة بأمر من يزيد64هـ | صفر 1448 | Yazid's army attacking the Kaaba; scans put it on BOTH 3 Safar and 3 Rabi I; research had 26 Muharram |
| 2/12 | وفاة النبي هارون بن عمران(ع) | صفر 1448 | earlier prophets' events (not in the user's include list) |
| 2/25 | وفاة السيدة مريم بنت عمران (ع) | صفر 1448 | earlier prophets' events (not in the user's include list) |
| 2/26 | تجهيز النبي(ص)لجيش أسامة | صفر 1448 | Usama's army - research excluded it as general history |
| 2/27 | إستشهاد النبي يحيى(ع) | صفر 1448 | earlier prophets' events (not in the user's include list) |
| 2/29 | نزول العذاب على قوم صالح | صفر 1448 | earlier prophets' events (not in the user's include list) |
| 3/3 | اول صلاة ميت على اسعد بن زراره | ربيع الأول 1448 | first funeral prayer (companion As'ad b. Zurara) - early-Islam history, not Ahl al-Bayt |
| 3/3 | رمي كعبة بالمنجنيق واحراق الكعبة من قبل مسلم بن عقبة64هـ | ربيع الأول 1448 | Yazid's army attacking the Kaaba; scans put it on BOTH 3 Safar and 3 Rabi I; research had 26 Muharram |
| 3/11 | ولادة السيدة نفيسة(س) | ربيع الأول 1448 | Sayyida Nafisa (descendant of Imam al-Hasan) - mostly an Egyptian/Sufi commemoration |
| 3/12 | إسبوع الوحدة الإسلامية | ربيع الأول 1448 | Islamic Unity Week - modern (1980s) institution |
| 3/14 | مولد النبي إبراهيم الخليل(ع) | ربيع الأول 1448 | earlier prophets' events (not in the user's include list) |
| 3/18 | حرب النبي إبراهيم(ع)مع النمرود | ربيع الأول 1448 | earlier prophets' events (not in the user's include list) |
| 3/18 | هلاك قوم ثمود | ربيع الأول 1448 | earlier prophets' events (not in the user's include list) |
| 3/19 | اخراج جسد زيد(ع)من قبره وصلبه121هـ | ربيع الأول 1448 | Zayd b. Ali (see above) |
| 3/19 | حرب النبي داود(ع)مع جالوت وقتل جالوت | ربيع الأول 1448 | earlier prophets' events (not in the user's include list) |
| 3/21 | هلاك قوم لوط(ع) | ربيع الأول 1448 | earlier prophets' events (not in the user's include list) |
| 3/23 | عتق ابو طالب(ع)عتيقة النبي(ص) | ربيع الأول 1448 | wording unclear/uncertain (Abu Talib + the Prophet) |
| 3/28 | إستقرار سفينة نوح(ع) على جبل الجودى بعد الطوفان | ربيع الأول 1448 | earlier prophets' events (not in the user's include list) |
| 5/9 | هدم مسجد رد الشمس لأمير المؤمنين(ع)في المدينة1422هـ | جمادى الأولى 1446, جمادى الأولى 1448 | modern attack on a site of the Imams (research also flagged such items "user may decide") |
| 5/10 | اعطاء الزهراء القميص لأبنتها حتى تعطيه الحسين(ع) | جمادى الأولى 1446, جمادى الأولى 1448 | unclear event about al-Zahra (s) and her daughter; printed text uncertain |
| 5/11 | وفاة النبي شيث(ع) | جمادى الأولى 1446, جمادى الأولى 1448 | earlier prophets' events (not in the user's include list) |
| 5/16 | غزوة ذات الرقاع 4هـ | جمادى الأولى 1446, جمادى الأولى 1448 | battle of the Prophet; the scans themselves put it on BOTH 1 Muharram and 16 Jumada I |
| 5/18 | بدء نزول الألواح على النبي موسى(ع) | جمادى الأولى 1446, جمادى الأولى 1448 | earlier prophets' events (not in the user's include list) |
| 5/18 | ولادة ذوالقرنين | جمادى الأولى 1446, جمادى الأولى 1448 | earlier prophets' events (not in the user's include list) |
| 5/26 | ولادة النبي صالح (ع) | جمادى الأولى 1446, جمادى الأولى 1448 | earlier prophets' events (not in the user's include list) |
| 5/27 | تفجير ماذنتي حرم الامامين الهادي والعسكري1428هـ | جمادى الأولى 1448 | modern attack on a site of the Imams (research also flagged such items "user may decide") |
| 5/27 | تفجيرماذنتي حرم الامامين الهادي والعسكري1428هـ | جمادى الأولى 1446 | modern attack on a site of the Imams (research also flagged such items "user may decide") |
| 5/29 | ولادة النبي إسماعيل(ع) | جمادى الأولى 1446, جمادى الأولى 1448 | earlier prophets' events (not in the user's include list) |

## Coverage / التغطية

Counts are of note PARTS (after splitting); a part printed in both Jumada I scans counts twice in the per-scan rows.

| scan | month | note parts | Shia-relevant (A+B+C) | match DB (A) | conflicts (B) | missing (C) | excluded (D) | borderline (E) |
|---|---|---|---|---|---|---|---|---|
| محرم 1446 | 1 | 37 | 14 | 9 | 0 | 5 | 11 | 12 |
| صفر 1448 | 2 | 42 | 17 | 9 | 3 | 5 | 18 | 7 |
| ربيع الأول 1448 | 3 | 43 | 18 | 6 | 3 | 9 | 13 | 12 |
| جمادى الأولى 1446 | 5 | 39 | 11 | 3 | 3 | 5 | 19 | 9 |
| جمادى الأولى 1448 | 5 | 38 | 11 | 3 | 3 | 5 | 18 | 9 |
| **total** | | 199 | 71 | 30 | 12 | 29 | 79 | 49 |

Unique items (month 5 duplicates merged): A=27, B=8 events (see table; 9 distinct scan parts), C=24, D=68, E=41.

## Transcription caveats
- Scan (1) Jumada I 1448 rows come from the pre-cleanup seed (git HEAD), spot-checked rows 12-19 against the image: identical.
- `uncertain: true` rows (small type or text overflowing the cell): Safar 30; Jumada I 1446: 12, 22, 23, 28, 30; Muharram 1446: 6, 7, 19, 28; Rabi I 1448: 3, 16, 21 («استشها» as printed), 23 («عتق ابو طالب(ع)عتيقة النبي(ص)» – meaning unclear); Jumada I 1448: rows flagged in the seed (10, 19, 21, 24).
- Spelling kept as printed (e.g. «التاسوعا», «وجيشة», «الكوفه», «مؤته», «الأسلامية», «المعتصم», «ميرزااسفند»).
