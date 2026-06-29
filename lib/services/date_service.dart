import 'package:intl/intl.dart';

class DateService {
  static String getDateNextDimanche() {
    var now = DateTime.now();
    int daysToAdd = (DateTime.sunday - now.weekday) % 7;
    var nextSunday = now.add(Duration(days: daysToAdd));
    return DateFormat('y-MM-dd').format(nextSunday);
  }

  static String getDateNextSamedi() {
    var now = DateTime.now();
    int daysToAdd = (DateTime.saturday - now.weekday) % 7;
    var nextSaturday = now.add(Duration(days: daysToAdd));
    return DateFormat('y-MM-dd').format(nextSaturday);
  }

  static String getDateNextPeanuts(DateTime actifPeanuts) {
    actifPeanuts = actifPeanuts.add(const Duration(days: 1));
    return _formatDate(actifPeanuts);
  }

  static String getDatePrevPeanuts(DateTime actifPeanuts) {
    actifPeanuts = actifPeanuts.add(const Duration(days: -1));
    return _formatDate(actifPeanuts);
  }

  static String getDateNextActif(DateTime nowActif) {
    var quelJour = nowActif.weekday;
    switch (quelJour) {
      case 6:
        nowActif = nowActif.add(const Duration(days: 1));
        break;
      case 7:
        nowActif = nowActif.add(const Duration(days: 6));
        break;
    }
    return _formatDate(nowActif);
  }

  static String getDatePrevActif(DateTime nowActif) {
    DateTime nowa = DateTime.now();
    var quelJour = nowActif.weekday;
    DateTime nowTemp = nowActif;

    switch (quelJour) {
      case 6:
        nowActif = nowActif.subtract(const Duration(days: 6));
        break;
      case 7:
        nowActif = nowActif.subtract(const Duration(days: 1));
        break;
    }

    if (nowActif.isBefore(nowa)) {
      nowActif = nowTemp;
    }
    return _formatDate(nowActif);
  }

  static String formatDateBrocante(String dateselect, List<String> jours, List<String> mois) {
    DateTime naw = DateTime.parse(dateselect);
    String formatter = "${jours[naw.weekday].substring(0, 3)} ${naw.day} ${mois[naw.month]}";
    return formatter;
  }

  static String dateToString(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String _formatDate(DateTime date) {
    if (date.day < 10 && date.month >= 10) {
      return DateFormat('y-M-0d').format(date);
    }
    if (date.month < 10 && date.day >= 10) {
      return DateFormat('y-0M-d').format(date);
    }
    if (date.day < 10 && date.month < 10) {
      return DateFormat('y-0M-0d').format(date);
    }
    return DateFormat('y-M-d').format(date);
  }
}