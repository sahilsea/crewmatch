import 'dart:convert';

import 'package:crewmatch/api/api_client.dart';
import 'package:crewmatch/api/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  ApiClient clientAnswering(int status, String body, {List<http.Request>? log}) => ApiClient(
        baseUrl: 'http://api.test/api/',
        httpClient: MockClient((request) async {
          log?.add(request);
          return http.Response(body, status, headers: {'content-type': 'application/json'});
        }),
      );

  test('sends the token and a JSON body, and decodes the answer', () async {
    final log = <http.Request>[];
    final client = clientAnswering(200, '{"ok":true}', log: log)..token = 'abc';

    final data = await client.post('/swipe', {'targetId': 'u2', 'direction': 'right'});

    expect(data, {'ok': true});
    final request = log.single;
    expect(request.url.toString(), 'http://api.test/api/swipe');
    expect(request.headers['Authorization'], 'Bearer abc');
    expect(request.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(request.body), {'targetId': 'u2', 'direction': 'right'});
  });

  test('turns { error, details } into an ApiException with field errors', () async {
    final client = clientAnswering(400, jsonEncode({
      'error': 'Validation failed',
      'details': [
        {'field': 'email', 'message': 'Invalid email address'},
        {'field': 'interests.0', 'message': 'Invalid option'},
        {'field': 'interests.1', 'message': 'Second problem'},
      ],
    }));

    late ApiException error;
    try {
      await client.put('/users/me', {});
      fail('expected an ApiException');
    } on ApiException catch (e) {
      error = e;
    }

    expect(error.status, 400);
    expect(error.message, 'Validation failed');
    expect(error.fieldErrors, {'email': 'Invalid email address', 'interests': 'Invalid option'});
  });

  test('falls back to a generic message for a body that is not the API shape', () async {
    final client = clientAnswering(502, '<html>Bad gateway</html>');
    await expectLater(
      client.get('/health'),
      throwsA(isA<ApiException>()
          .having((e) => e.status, 'status', 502)
          .having((e) => e.message, 'message', 'Request failed (502)')),
    );
  });

  test('an empty 204 answer is an empty map', () async {
    expect(await clientAnswering(204, '').delete('/crews/mine'), isEmpty);
  });

  test('a 401 on a signed-in request reports the expired session', () async {
    var expired = 0;
    final client = clientAnswering(401, '{"error":"Session expired or invalid, please sign in again"}')
      ..token = 'old'
      ..onUnauthorized = () => expired++;

    await expectLater(client.get('/auth/me'), throwsA(isA<ApiException>()));
    expect(expired, 1);
  });

  test('a 401 without a token (a wrong password) does not', () async {
    var expired = 0;
    final client = clientAnswering(401, '{"error":"Wrong email or password"}')
      ..onUnauthorized = () => expired++;

    await expectLater(
      client.post('/auth/login', {'email': 'a@b.c', 'password': 'nope'}),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Wrong email or password')),
    );
    expect(expired, 0);
  });

  test('an unreachable server is an offline ApiException', () async {
    final client = ApiClient(
      baseUrl: 'http://api.test/api',
      httpClient: MockClient((_) async => throw http.ClientException('Connection refused')),
    );
    await expectLater(
      client.get('/health'),
      throwsA(isA<ApiException>().having((e) => e.isOffline, 'isOffline', true)),
    );
  });
}
