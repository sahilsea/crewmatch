import 'dart:convert';

import 'package:crewmatch/api/api_client.dart';
import 'package:crewmatch/api/crewmatch_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A canned answer: status code and JSON body (null for an empty body).
typedef Reply = (int, Object?);

const testBaseUrl = 'http://api.test/api';

/// A [CrewMatchApi] answering from [routes], keyed by "METHOD /path" with the
/// `/api` prefix and query string left out. Every request lands in [log].
CrewMatchApi fakeApi(
  Map<String, Reply Function(http.Request request)> routes, {
  List<http.Request>? log,
}) =>
    CrewMatchApi(ApiClient(baseUrl: testBaseUrl, httpClient: fakeHttp(routes, log: log)));

MockClient fakeHttp(
  Map<String, Reply Function(http.Request request)> routes, {
  List<http.Request>? log,
}) =>
    MockClient((request) async {
      log?.add(request);
      final key = '${request.method} ${request.url.path.replaceFirst('/api', '')}';
      final handler = routes[key];
      final (status, body) = handler == null ? (404, {'error': 'No route for $key'}) : handler(request);
      return http.Response(
        body == null ? '' : jsonEncode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
