@TestOn('browser')
library seltzer.test.platform.browser_test;

import 'package:seltzer/platform/browser.dart';
import 'package:test/test.dart';

import 'common_utils.dart';

void main() {
  useSeltzerInTheBrowser();
  runPlatformTests();
}
