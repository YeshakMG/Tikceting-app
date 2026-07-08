/// A utility class for converting between Gregorian and Ethiopian calendar dates.
class EthiopianDateConverter {
  /// Converts a Gregorian date to Ethiopian date.
  /// 
  /// The Ethiopian calendar is 7-8 years behind the Gregorian calendar
  /// and has 13 months (12 months of 30 days each and a 13th month of 5-6 days).
  static EthiopianDate toEthiopian(DateTime gregorianDate) {
    // Constants for Ethiopian calendar calculation
    const int jdOffset = 1723856; // Julian day offset
    
    // Calculate Julian day number
    int jdn = _gregorianToJDN(gregorianDate);
    
    // Calculate Ethiopian date from Julian day number
    int r = (jdn - jdOffset) % 1461;
    int n = r % 365 + 365 * (r / 1461).floor();
    
    int year = 4 * ((jdn - jdOffset) / 1461).floor();
    year = year + (n / 365).floor();
    
    int month = (n / 30).floor() + 1;
    int day = (n % 30) + 1;
    
    return EthiopianDate(year: year, month: month, day: day);
  }
  
  /// Converts an Ethiopian date to Gregorian date.
  static DateTime toGregorian(EthiopianDate ethiopianDate) {
    // Constants for Ethiopian calendar calculation
    const int jdOffset = 1723856; // Julian day offset
    
    // Calculate Julian day number from Ethiopian date
    int jdn = _ethiopianToJDN(ethiopianDate);
    
    // Convert Julian day number to Gregorian date
    return _jdnToGregorian(jdn);
  }
  
  /// Converts a Gregorian date to Julian day number.
  static int _gregorianToJDN(DateTime date) {
    int a = (14 - date.month) ~/ 12;
    int y = date.year + 4800 - a;
    int m = date.month + 12 * a - 3;
    
    return date.day + ((153 * m + 2) ~/ 5) + 365 * y + (y ~/ 4) - (y ~/ 100) + (y ~/ 400) - 32045;
  }
  
  /// Converts an Ethiopian date to Julian day number.
  static int _ethiopianToJDN(EthiopianDate date) {
    const int jdOffset = 1723856; // Julian day offset
    
    int year = date.year;
    int month = date.month;
    int day = date.day;
    
    return jdOffset + 365 * year + (year / 4).floor() + 30 * month + day - 31;
  }
  
  /// Converts a Julian day number to Gregorian date.
  static DateTime _jdnToGregorian(int jdn) {
    int a = jdn + 32044;
    int b = (4 * a + 3) ~/ 146097;
    int c = a - ((146097 * b) ~/ 4);
    
    int d = (4 * c + 3) ~/ 1461;
    int e = c - ((1461 * d) ~/ 4);
    int m = (5 * e + 2) ~/ 153;
    
    int day = e - ((153 * m + 2) ~/ 5) + 1;
    int month = m + 3 - 12 * (m ~/ 10);
    int year = 100 * b + d - 4800 + (m ~/ 10);
    
    return DateTime(year, month, day);
  }
  
  /// Returns the current date in Ethiopian calendar.
  static EthiopianDate now() {
    return toEthiopian(DateTime.now());
  }
  
  /// Formats an Ethiopian date as a string in the format "YYYY/MM/DD".
  static String format(EthiopianDate date) {
    return "${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}";
  }
}

/// A class representing a date in the Ethiopian calendar.
class EthiopianDate {
  final int year;
  final int month;
  final int day;
  
  EthiopianDate({
    required this.year,
    required this.month,
    required this.day,
  });
  
  @override
  String toString() {
    return "$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";
  }
  
  /// Returns the name of the month in Amharic.
  String get monthName {
    final List<String> monthNames = [
      'Meskerem', 'Tikimt', 'Hidar', 'Tahsas',
      'Tir', 'Yekatit', 'Megabit', 'Miazia',
      'Ginbot', 'Sene', 'Hamle', 'Nehase', 'Pagume'
    ];
    
    return monthNames[month - 1];
  }
}