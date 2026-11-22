import '../config.dart';

/// A picture URL as an absolute address. The API stores its own uploads as
/// paths (`/api/photos/…`); those resolve against the API's host.
String mediaUrl(String url) {
  if (url.isEmpty || url.startsWith('http')) return url;
  return Uri.parse(apiUrl).resolve(url).toString();
}
