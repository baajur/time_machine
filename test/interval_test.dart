// Portions of this work are Copyright 2018 The Time Machine Authors. All rights reserved.
// Portions of this work are Copyright 2018 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0, as found in the LICENSE.txt file.

import 'dart:async';

import 'package:time_machine/src/time_machine_internal.dart';
import 'package:test/test.dart';
import 'package:matcher/matcher.dart';

import 'time_machine_testing.dart';

Future main() async {
  await TimeMachine.initialize();
  await runTests();
}

final Instant one = IInstant.untrusted(new Time(nanoseconds: 1));
final Instant threeMillion = IInstant.untrusted(new Time(nanoseconds: 3000000));
final Instant negativeFiftyMillion = IInstant.untrusted(new Time(nanoseconds: -50000000));

final Instant SampleStart = TimeConstants.unixEpoch.add(Time(nanoseconds: -30001));
final Instant SampleEnd = TimeConstants.unixEpoch.add(Time(nanoseconds: 40001));

@Test()
void Construction_Success()
{
  var interval = new Interval(SampleStart, SampleEnd);
  expect(SampleStart, interval.start);
  expect(SampleEnd, interval.end);
}

@Test()
void Construction_EqualStartAndEnd()
{
  var interval = new Interval(SampleStart, SampleStart);
  expect(SampleStart, interval.start);
  expect(SampleStart, interval.end);
  expect(Time.zero, interval.totalTime);
}

@Test()
void Construction_EndBeforeStart()
{
  expect(() => new Interval(SampleEnd, SampleStart), throwsRangeError);
  expect(() => new Interval(SampleEnd, SampleStart), throwsRangeError);
}

@Test()
void Equals()
{
  TestHelper.TestEqualsStruct(
      new Interval(SampleStart, SampleEnd),
      new Interval(SampleStart, SampleEnd),
      [new Interval(TimeConstants.unixEpoch, SampleEnd)]);
  TestHelper.TestEqualsStruct(
      new Interval(null, SampleEnd),
      new Interval(null, SampleEnd),
      [new Interval(TimeConstants.unixEpoch, SampleEnd)]);
  TestHelper.TestEqualsStruct(
      new Interval(SampleStart, SampleEnd),
      new Interval(SampleStart, SampleEnd),
      [new Interval(TimeConstants.unixEpoch, SampleEnd)]);
  TestHelper.TestEqualsStruct(
      new Interval(null, null),
      new Interval(null, null),
      [new Interval(TimeConstants.unixEpoch, SampleEnd)]);
}

@Test()
void Operators()
{
  TestHelper.TestOperatorEquality(
      new Interval(SampleStart, SampleEnd),
      new Interval(SampleStart, SampleEnd),
      new Interval(TimeConstants.unixEpoch, SampleEnd));
}

@Test()
void Duration()
{
  var interval = new Interval(SampleStart, SampleEnd);
  expect(Time(nanoseconds: 70002), interval.totalTime);
}

/*
@Test()
void DefaultConstructor()
{
  var actual = new Interval();
  expect(NodaTime.time.Zero, actual.time);
}*/

@Test()
void ToStringUsesExtendedIsoFormat()
{
  // var start = new LocalDateTime.fromYMDHMS(2013, 4, 12, 17, 53, 23).PlusNanoseconds(123456789).InUtc().ToInstant();
  // var end = new LocalDateTime.fromYMDHMSM(2013, 10, 12, 17, 1, 2, 120).InUtc().ToInstant();

  var start = LocalDateTime(2013, 4, 12, 17, 53, 23).addNanoseconds(123456789).inUtc().toInstant();
  var end = LocalDateTime(2013, 10, 12, 17, 1, 2).addMilliseconds(120).inUtc().toInstant();

  var value = new Interval(start, end);
  expect("2013-04-12T17:53:23.123456789Z/2013-10-12T17:01:02.12Z", value.toString());
}

@Test()
void ToString_Infinite()
{
  var value = new Interval(null, null);
  expect("StartOfTime/EndOfTime", value.toString());
}

@Test()
@TestCase(const ["1990-01-01T00:00:00Z", false], "Before interval")
@TestCase(const ["2000-01-01T00:00:00Z", true], "Start of interval")
@TestCase(const ["2010-01-01T00:00:00Z", true], "Within interval")
@TestCase(const ["2020-01-01T00:00:00Z", false], "End instant of interval")
@TestCase(const ["2030-01-01T00:00:00Z", false], "After interval")
void Contains(String candidateText, bool expectedResult)
{
  var start = new Instant.utc(2000, 1, 1, 0, 0);
  var end = new Instant.utc(2020, 1, 1, 0, 0);
  var interval = new Interval(start, end);
  var candidate = InstantPattern.extendedIso.parse(candidateText).value;
  expect(expectedResult, interval.contains(candidate));
}

@Test()
void Contains_Infinite()
{
  var interval = new Interval(null, null);
  expect(interval.contains(Instant.maxValue), isTrue);
  expect(interval.contains(Instant.minValue), isTrue);
}

@Test()
void HasStart()
{
  expect(new Interval(Instant.minValue, null).hasStart, isTrue);
  expect(new Interval(null, Instant.minValue).hasStart, isFalse);
}

@Test()
void HasEnd()
{
  expect(new Interval(null, Instant.maxValue).hasEnd, isTrue);
  expect(new Interval(Instant.maxValue, null).hasEnd, isFalse);
}

@Test()
void Start()
{
  expect(TimeConstants.unixEpoch, new Interval(TimeConstants.unixEpoch, null).start);
  Interval noStart = new Interval(null, TimeConstants.unixEpoch);
  expect(() => noStart.start.toString(), throwsStateError);
}

@Test()
void End()
{
  expect(TimeConstants.unixEpoch, new Interval(null, TimeConstants.unixEpoch).end);
  Interval noEnd = new Interval(TimeConstants.unixEpoch, null);
  expect(() => noEnd.end.toString(), throwsStateError);
}

@Test()
void Contains_EmptyInterval()
{
  var instant = TimeConstants.unixEpoch;
  var interval = new Interval(instant, instant);
  expect(interval.contains(instant), isFalse);
}

@Test()
void Contains_EmptyInterval_MaxValue()
{
  var instant = Instant.maxValue;
  var interval = new Interval(instant, instant);
  expect(interval.contains(instant), isFalse);
}

@Test()
@TestCase(const ["2020-01-01T00:00:00Z", "2030-01-01T00:00:00Z", false], "0")
@TestCase(const ["1910-01-01T00:00:00Z", "2000-01-01T00:00:00Z", false], "1")
@TestCase(const ["1910-01-01T00:00:00Z", "2000-01-01T00:00:01Z", true], "2")
@TestCase(const ["2020-01-01T00:00:00Z", "2030-01-01T00:00:01Z", false], "3")
@TestCase(const ["2019-12-31T23:59:59Z", "2030-01-01T00:00:01Z", true], "4")
void Interval_Overlapping(String otherStart, String otherEnd, bool expectedResult) {
  var start = new Instant.utc(2000, 1, 1, 0, 0);
  var end = new Instant.utc(2020, 1, 1, 0, 0);
  var interval = new Interval(start, end);
  var other = Interval(InstantPattern.extendedIso.parse(otherStart).value, InstantPattern.extendedIso.parse(otherEnd).value);
  expect(interval.overlaps(other), expectedResult);
}


/*
@Test()
void Deconstruction_IntervalWithoutStart() {
  Instant ? start;
  var end = new Instant(1500, 1_000_000);
  var value = new Interval(start, end);

  (Instant ? actualStart, Instant? actualEnd) = value;

  expect(start, actualStart);
  expect(end, actualEnd);
}*/

/*
@Test()
void Deconstruction_IntervalWithoutEnd() {
  var start = new Instant(1500, 1_000_000);
  Instant ? end;
  var value = new Interval(start, end);

  (Instant ? actualStart, Instant? actualEnd) = value;

  expect(start, actualStart);
  expect(end, actualEnd);
}*/
