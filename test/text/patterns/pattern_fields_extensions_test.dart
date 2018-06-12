// Portions of this work are Copyright 2018 The Time Machine Authors. All rights reserved.
// Portions of this work are Copyright 2018 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0, as found in the LICENSE.txt file.

import 'dart:async';
import 'dart:math' as math;
import 'dart:mirrors';

import 'package:time_machine/time_machine.dart';
import 'package:time_machine/time_machine_calendars.dart';
import 'package:time_machine/time_machine_patterns.dart';
import 'package:time_machine/time_machine_text.dart';
import 'package:time_machine/time_machine_utilities.dart';

import 'package:test/test.dart';
import 'package:matcher/matcher.dart';
import 'package:time_machine/time_machine_timezones.dart';

import '../../time_machine_testing.dart';
import '../text_cursor_test_base_tests.dart';

Future main() async {
  await runTests();
}

@Test()
void IsUsed_NoMatch()
{
  expect((PatternFields.hours12 | PatternFields.minutes).hasAny(PatternFields.hours24), isFalse);
}

@Test()
void IsUsed_SingleValueMatch()
{
  expect(PatternFields.hours24.hasAny(PatternFields.hours24), isTrue);
}

@Test()
void IsFieldUsed_MultiValueMatch()
{
  expect((PatternFields.hours24 | PatternFields.minutes).hasAny(PatternFields.hours24), isTrue);
}

@Test()
void AllAreUsed_NoMatch()
{
  expect((PatternFields.hours12 | PatternFields.minutes).hasAll(PatternFields.hours24 | PatternFields.seconds), isFalse);
}

@Test()
void AllAreUsed_PartialMatch()
{
  expect((PatternFields.hours12 | PatternFields.minutes).hasAll(PatternFields.hours12 | PatternFields.seconds), isFalse);
}

@Test()
void AllAreUsed_CompleteMatch()
{
  expect((PatternFields.hours12 | PatternFields.minutes).hasAll(PatternFields.hours12 | PatternFields.minutes), isTrue);
}

@Test()
void AllAreUsed_CompleteMatchWithMore()
{
  expect((PatternFields.hours24 | PatternFields.minutes | PatternFields.hours12).hasAll(PatternFields.hours24 | PatternFields.minutes), isTrue);
}

