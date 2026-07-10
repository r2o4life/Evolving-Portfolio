@JS()
library puter_interop;

import 'package:js/js.dart';
import 'dart:js_util';

@JS('generateSdfViaPuter')
external Object _generateSdfViaPuter(String promptText);

Future<String> generateSdfViaPuterInterop(String promptText) async {
  final promise = _generateSdfViaPuter(promptText);
  final result = await promiseToFuture(promise);
  return result as String;
}
