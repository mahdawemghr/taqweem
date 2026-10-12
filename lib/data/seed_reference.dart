import '../domain/calendar_fill.dart';
import '../domain/models.dart';
import '../domain/weekday.dart';

/// Reference data transcribed from
/// `templates/WhatsApp Image 2026-10-12 at 9.09.58 PM.jpeg`
/// (جمادى الأول 1448, 13 Oct – 11 Nov 2026).
///
/// Wording, spelling and spacing are kept as printed in the scan (e.g.
/// `شهيدالمحراب`, `البحرانى`, `عبدا...`). Notes printed in very small type
/// whose exact letters could not be confirmed are flagged with
/// [DayField.note] in `uncertain` instead of being "corrected".

PosterTexts defaultTexts() => const PosterTexts(
  title: defaultTitle,
  rightQuote: HeaderQuote(
    text:
        'نحن وسيلته في خلقه، ونحن خاصته، ومحل قدسه، '
        'ونحن حجته في غيبه، ونحن ورثة أنبيائه',
    attribution: 'فاطمة الزهراء(س)',
  ),
  leftQuote: HeaderQuote(
    // "ا..." is printed literally in the scan (abbreviation).
    text: 'صلاة النوافل قربان وإلى ا... لكل مؤمن',
    attribution: 'الإمام الكاظم(ع)',
  ),
  braceQuote:
      'إذا عرضتم الإسلام على حقيقته للعالم، وإذا طبقتموه كما هو، '
      'فإن السيادة والرفعة ستكون من نصيبكم.',
  article: ClosingArticle(
    author: 'الشهيد مرتضى مطهرى',
    body:
        'فالحسين (ع) إنما قام للمقارعة ضد الذنوب وإذا بنا جئنا لنجعل منه '
        'متراساً لارتكاب الذنوب وللمذنبين! وتمادينا كثيراً في هذا الاتجاه '
        'عندما قلنا بأن الحسين (ع) قد أسس شركة للضمان وأي ضمان ؟ '
        'ضمان ضد الذنوب! وصرنا ندعو الناس للتسجيل في هذه الشركة مقابل '
        'أقساط من الدمع!',
  ),
  sideRight: SideQa(
    question:
        'هل يمكن البناء على طهارة برك المياه الموجودة في الشوارع '
        'في حال لامست ملابسي؟',
    answer: 'نعم هي محكومة بالطهارة.',
  ),
  sideLeft: SideQa(
    question: 'هل يجب ذكر الأئمة عليهم السلام في نهاية كل الصلاة؟',
    answer:
        'لا يجب ولكن يستحب في التعقيب بعد الصلاة الشهادتان '
        'والاقرار بالأئمة عليهم السلام.',
  ),
  footerNotes: defaultFooterNotes,
  fatiha: defaultFatiha,
);

class _Row {
  final String fajr, shurooq, zuhr, maghrib, note;
  final bool hl;
  final Set<DayField> u;
  const _Row(
    this.fajr,
    this.shurooq,
    this.zuhr,
    this.maghrib,
    this.note, {
    this.hl = false,
    this.u = const {},
  });
}

int _t(String hm) {
  final p = hm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

/// One entry per hijri day (index 0 = day 1). Times as printed (h:mm).
const _rows = <_Row>[
  _Row(
    '4:18',
    '5:35',
    '11:25',
    '5:27',
    'غداً استشهاد شهيدالمحراب الخامس آية الله اشرف اصفهاني1982م',
  ),
  _Row('4:18', '5:35', '11:25', '5:26', 'بدأ نزول الوحي على النبي محمد(ص)'),
  _Row('4:19', '5:36', '11:25', '5:25', ''),
  _Row('4:19', '5:36', '11:24', '5:24', 'وفاة الشيخ ميثم البحرانى 679هـ'),
  _Row(
    '4:20',
    '5:37',
    '11:24',
    '5:23',
    'مولد السيدة زينب الكبرى(ع) - يوم الممرضة المسلمة',
    hl: true,
  ),
  _Row('4:20', '5:37', '11:24', '5:22', 'غزوة مؤته8هـ'),
  _Row(
    '4:21',
    '5:38',
    '11:24',
    '5:21',
    'استشهاد السيد مصطفى الخميني(ر ض)1977/10/23م',
  ),
  _Row('4:21', '5:38', '11:24', '5:20', 'وفاة السيد الخونساري1313هـ'),
  _Row(
    '4:22',
    '5:39',
    '11:24',
    '5:19',
    'هدم مسجد رد الشمس لأمير المؤمنين(ع)في المدينة1422هـ',
  ),
  _Row(
    '4:22',
    '5:40',
    '11:23',
    '5:18',
    'حرب الجمل 36هـ - اعطاء الزهراء القميص لأبنتها حتى تعطيه الحسين(ع)',
    u: {DayField.note},
  ),
  _Row(
    '4:23',
    '5:40',
    '11:23',
    '5:18',
    'وفاة النبي شيث(ع) - وفاة المفسر المعروف بالفخر الرازي(رض)',
  ),
  _Row(
    '4:23',
    '5:41',
    '11:23',
    '5:17',
    'وفاة عبدا... بن عبدالمطلب والد الرسول الأكرم(ص)',
  ),
  _Row(
    '4:24',
    '5:41',
    '11:23',
    '5:16',
    'ذكرى استشهاد سيدة نساء العالمين فاطمة الزهراء(ع)11هـ',
    hl: true,
  ),
  _Row('4:24', '5:42', '11:23', '5:15', 'وفاة الدكتوراحمدالوائلي1424هـ'),
  _Row(
    '4:25',
    '5:42',
    '11:23',
    '5:14',
    'فتح البصرة على يدالإمام علي بن أبي طالب(ع)',
  ),
  _Row('4:25', '5:43', '11:23', '5:13', 'غزوة ذات الرقاع 4هـ'),
  _Row('4:26', '5:44', '11:23', '5:13', ''),
  _Row(
    '4:26',
    '5:44',
    '11:23',
    '5:12',
    'ولادة ذوالقرنين - بدء نزول الألواح على النبي موسى(ع)',
  ),
  _Row(
    '4:27',
    '5:45',
    '11:22',
    '5:11',
    'مقتل زيد بن صوحان36هـ - غداً استشهاد آيةا...قاضي الطباطبائي اول شهيد المحراب1979م',
    u: {DayField.note},
  ),
  _Row(
    '4:27',
    '5:46',
    '11:22',
    '5:11',
    'إستشهاد الشهيد الأول(محمد بن مكي العاملي)786هـ(رض)',
  ),
  _Row(
    '4:28',
    '5:46',
    '11:22',
    '5:10',
    'احراق المسجد الأقصى بيد اليهود69هـ - استشهاد الصحابي الجليل زيد بن صوحان',
    u: {DayField.note},
  ),
  _Row(
    '4:28',
    '5:47',
    '11:22',
    '5:09',
    'وفاة القاسم ابن الامام موسى الكاظم(ع)192هـ - وفاة الشاعرسيد رضا الهندي1362هـ',
    hl: true,
  ),
  _Row(
    '4:29',
    '5:48',
    '11:22',
    '5:09',
    'وفاة الفقيه ابن شاذان 376هـ - يوم أمس رحيل آيةا... محمد تقي بهجت 1430هـ',
  ),
  _Row(
    '4:30',
    '5:48',
    '11:22',
    '5:08',
    'وفاة السيد محمد تقي القمي1344هـ - يوم امس استبعادالامام الخميني من ايران الى تركيا1964م',
    u: {DayField.note},
  ),
  _Row('4:30', '5:49', '11:22', '5:07', 'وفاة معاوية بن يزيد(الخير)64هـ'),
  _Row(
    '4:31',
    '5:50',
    '11:23',
    '5:07',
    'ولادة النبي صالح (ع) - وفاة المحقق النائيني1355هـ',
  ),
  _Row(
    '4:31',
    '5:50',
    '11:23',
    '5:07',
    'تفجير ماذنتي حرم الامامين الهادي والعسكري1428هـ',
  ),
  _Row(
    '4:32',
    '5:51',
    '11:23',
    '5:06',
    'وفاة السفير الثاني محمد بن عثمان304هـ',
  ),
  _Row('4:32', '5:52', '11:23', '5:06', 'ولادة النبي إسماعيل(ع)'),
  _Row('4:33', '5:52', '11:23', '5:05', 'وقف الحرب العالمية الأولى1918م'),
];

/// Seed month = the reference poster, so templates can be compared 1:1.
MonthPoster seedReferenceMonth() {
  final filled = CalendarFill.generate(
    MonthSetup(
      hijriMonthIndex: 4,
      hijriYear: 1448,
      firstWeekday: Weekday.tuesday,
      dayCount: 30,
      gregorianStart: const DateParts(2026, 10, 13),
      solarStart: const DateParts(1405, 7, 21),
    ),
  );
  final days = <DayRow>[
    for (var i = 0; i < filled.days.length; i++)
      filled.days[i].copyWith(
        times: PrayerTimes(
          fajr: _t(_rows[i].fajr),
          shurooq: _t(_rows[i].shurooq),
          zuhr: _t(_rows[i].zuhr),
          maghrib: _t(_rows[i].maghrib),
        ),
        note: _rows[i].note,
        highlighted: _rows[i].hl,
        uncertain: _rows[i].u,
      ),
  ];
  return MonthPoster(
    id: 'seed-jumada1-1448',
    updatedAt: DateTime.utc(2026, 10, 12),
    hijriMonthIndex: 4,
    hijriYear: 1448,
    gregorianHeader: filled.gregorianHeader,
    solarHeader: filled.solarHeader,
    days: days,
    texts: defaultTexts(),
    templateId: 'navy_gold',
  );
}
