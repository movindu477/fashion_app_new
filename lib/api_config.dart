class ApiConfig {
  // CHANGE THIS BASED ON WHERE YOU RUN THE APP
  static const bool isEmulator = true; // 👈 REAL PHONE = false

  static const String emulatorBaseUrl = "http://10.0.2.2:3000";
  // UPDATED IP ADDRESS
  static const String realDeviceBaseUrl = "http://192.168.185.224:3000";

  static String get baseUrl {
    return isEmulator ? emulatorBaseUrl : realDeviceBaseUrl;
  }
}
