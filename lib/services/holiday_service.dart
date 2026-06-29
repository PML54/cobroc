class HolidayService {
  static DateTime _easter(int year) {
    int a = year % 19;
    int b = year ~/ 100;
    int c = year % 100;
    int d = b ~/ 4;
    int e = b % 4;
    int f = (b + 8) ~/ 25;
    int g = (b - f + 1) ~/ 3;
    int h = (19 * a + b - d - g + 15) % 30;
    int i = c ~/ 4;
    int k = c % 4;
    int l = (32 + 2 * e + 2 * i - h - k) % 7;
    int m = (a + 11 * h + 22 * l) ~/ 451;
    int month = (h + l - 7 * m + 114) ~/ 31;
    int day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }

  static Set<DateTime> _holidaysForYear(int year) {
    final easter = _easter(year);
    return {
      DateTime(year, 1, 1),
      easter.add(const Duration(days: 1)),   // Lundi de Pâques
      DateTime(year, 5, 1),
      DateTime(year, 5, 8),
      easter.add(const Duration(days: 39)),  // Ascension
      easter.add(const Duration(days: 50)),  // Lundi de Pentecôte
      DateTime(year, 7, 14),
      DateTime(year, 8, 15),
      DateTime(year, 11, 1),
      DateTime(year, 11, 11),
      DateTime(year, 12, 25),
    };
  }

  static bool isHoliday(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return _holidaysForYear(date.year).contains(d);
  }

  static bool isBrocanteDay(DateTime date) {
    return date.weekday == DateTime.saturday ||
        date.weekday == DateTime.sunday ||
        isHoliday(date);
  }

  static DateTime nextBrocanteDay(DateTime from) {
    DateTime dt = DateTime(from.year, from.month, from.day)
        .add(const Duration(days: 1));
    for (int i = 0; i < 400; i++) {
      if (isBrocanteDay(dt)) return dt;
      dt = dt.add(const Duration(days: 1));
    }
    return from;
  }

  static DateTime prevBrocanteDay(DateTime from, DateTime minDate) {
    final min = DateTime(minDate.year, minDate.month, minDate.day);
    DateTime dt = DateTime(from.year, from.month, from.day)
        .subtract(const Duration(days: 1));
    for (int i = 0; i < 400; i++) {
      if (dt.isBefore(min)) return from;
      if (isBrocanteDay(dt)) return dt;
      dt = dt.subtract(const Duration(days: 1));
    }
    return from;
  }

  // Retourne les jours de brocante (Sam/Dim/Fériés) de la semaine ISO
  // contenant [date] (lundi→dimanche), triés chronologiquement.
  static List<DateTime> brocantesDaysInWeek(DateTime date) {
    final norm = DateTime(date.year, date.month, date.day);
    // Lundi de la semaine ISO (weekday: 1=Lun … 7=Dim)
    final monday = norm.subtract(Duration(days: norm.weekday - 1));
    final List<DateTime> days = [];
    for (int i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      if (isBrocanteDay(day)) days.add(day);
    }
    return days;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // Navigation circulaire → dans la semaine de [current] (Sam/Dim/Fériés).
  // Boucle sur tous les jours broc de la semaine, sans filtre de date.
  static DateTime nextBrocanteDayInWeek(DateTime current) {
    final days = brocantesDaysInWeek(current);
    if (days.isEmpty) return current;
    final idx = days.indexWhere((d) => _sameDay(d, current));
    if (idx == -1) return days.first;
    return days[(idx + 1) % days.length];
  }

  // Navigation circulaire ← dans la semaine de [current] (Sam/Dim/Fériés).
  // Boucle sur tous les jours broc de la semaine, sans filtre de date.
  static DateTime prevBrocanteDayInWeek(DateTime current) {
    final days = brocantesDaysInWeek(current);
    if (days.isEmpty) return current;
    final idx = days.indexWhere((d) => _sameDay(d, current));
    if (idx == -1) return days.last;
    return days[(idx - 1 + days.length) % days.length];
  }

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static DateTime _mondayOf(DateTime date) {
    final norm = DateTime(date.year, date.month, date.day);
    return norm.subtract(Duration(days: norm.weekday - 1));
  }

  // Saute au premier jour broc de la SEMAINE SUIVANTE (toujours change de semaine).
  static DateTime nextWeekFirstBrocanteDay(DateTime current) {
    final mondayNext = _mondayOf(current).add(const Duration(days: 7));
    for (int i = 0; i < 7; i++) {
      final day = mondayNext.add(Duration(days: i));
      if (isBrocanteDay(day)) return day;
    }
    return mondayNext;
  }

  // Saute au premier jour broc de la SEMAINE PRÉCÉDENTE ≥ minDate.
  // Retourne [current] si impossible (toute la semaine précédente est passée).
  static DateTime prevWeekFirstBrocanteDay(DateTime current, DateTime minDate) {
    final min = DateTime(minDate.year, minDate.month, minDate.day);
    final mondayPrev = _mondayOf(current).subtract(const Duration(days: 7));
    for (int i = 0; i < 7; i++) {
      final day = mondayPrev.add(Duration(days: i));
      if (!day.isBefore(min) && isBrocanteDay(day)) return day;
    }
    return current;
  }
}
