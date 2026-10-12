enum Weekday {
  saturday('السبت'),
  sunday('الأحد'),
  monday('الأثنين'),
  tuesday('الثلاثاء'),
  wednesday('الأربعاء'),
  thursday('الخميس'),
  friday('الجمعة');

  const Weekday(this.ar);
  final String ar;
  Weekday get next => Weekday.values[(index + 1) % 7];
}
