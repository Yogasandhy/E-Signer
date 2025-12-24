class ApiConfig {
  // Ganti base URL cukup dari file ini saja.
  // Tinggal comment/uncomment salah satu baris `baseUrl` di bawah.

  static const String deployedBaseUrl = 'https://testing.rifqiyafik.my.id';
  static const String localBaseUrl = 'http://10.10.32.37:8000';

  // Pakai salah satu:
  static const String baseUrl = localBaseUrl;
  // static const String baseUrl = localBaseUrl;
}
