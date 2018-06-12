// Portions of this work are Copyright 2018 The Time Machine Authors. All rights reserved.
// Portions of this work are Copyright 2018 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0, as found in the LICENSE.txt file.

import 'dart:async';

import 'package:time_machine/time_machine.dart';
import 'package:time_machine/time_machine_utilities.dart';
import 'package:time_machine/time_machine_globalization.dart';
import 'package:time_machine/time_machine_timezones.dart';
import 'package:time_machine/time_machine_text.dart';
import 'package:time_machine/time_machine_patterns.dart';

@internal /*sealed*/ class ZonedDateTimePatternParser implements IPatternParser<ZonedDateTime> {
  @private final ZonedDateTime templateValue;
  @private final IDateTimeZoneProvider zoneProvider;
  @private final ZoneLocalMappingResolver resolver;

  @private static final Map<String /*char*/, CharacterHandler<ZonedDateTime, ZonedDateTimeParseBucket>> PatternCharacterHandlers =
  {
    '%': SteppedPatternBuilder.handlePercent /**<ZonedDateTime, ZonedDateTimeParseBucket>*/,
    '\'': SteppedPatternBuilder.HandleQuote /**<ZonedDateTime, ZonedDateTimeParseBucket>*/,
    '\"': SteppedPatternBuilder.HandleQuote /**<ZonedDateTime, ZonedDateTimeParseBucket>*/,
    '\\': SteppedPatternBuilder.HandleBackslash /**<ZonedDateTime, ZonedDateTimeParseBucket>*/,
    '/': (pattern, builder) => builder.addLiteral1(builder.formatInfo.dateSeparator, ParseResult.DateSeparatorMismatch /**<ZonedDateTime>*/),
    'T': (pattern, builder) => builder.addLiteral2('T', ParseResult.MismatchedCharacter /**<ZonedDateTime>*/),
    'y': DatePatternHelper.createYearOfEraHandler<ZonedDateTime, ZonedDateTimeParseBucket>((value) => value.yearOfEra, (bucket, value) =>
    bucket.Date.YearOfEra = value),
    'u': SteppedPatternBuilder.handlePaddedField<ZonedDateTime, ZonedDateTimeParseBucket>(
        4, PatternFields.year, -9999, 9999, (value) => value.year, (bucket, value) => bucket.Date.Year = value),
    'M': DatePatternHelper.createMonthOfYearHandler<ZonedDateTime, ZonedDateTimeParseBucket>((value) => value.month, (bucket, value) =>
    bucket.Date.MonthOfYearText = value, (bucket, value) => bucket.Date.MonthOfYearNumeric = value),
    'd': DatePatternHelper.createDayHandler<ZonedDateTime, ZonedDateTimeParseBucket>((value) => value.day, (value) => value.dayOfWeek.value, (bucket, value) =>
    bucket.Date.DayOfMonth = value, (bucket, value) => bucket.Date.DayOfWeek = value),
    '.': TimePatternHelper.createPeriodHandler<ZonedDateTime, ZonedDateTimeParseBucket>(
        9, (value) => value.nanosecondOfSecond, (bucket, value) => bucket.Time.FractionalSeconds = value),
    ';': TimePatternHelper.createCommaDotHandler<ZonedDateTime, ZonedDateTimeParseBucket>(
        9, (value) => value.nanosecondOfSecond, (bucket, value) => bucket.Time.FractionalSeconds = value),
    ':': (pattern, builder) => builder.addLiteral1(builder.formatInfo.timeSeparator, ParseResult.TimeSeparatorMismatch /**<ZonedDateTime>*/),
    'h': SteppedPatternBuilder.handlePaddedField<ZonedDateTime, ZonedDateTimeParseBucket>(
        2, PatternFields.hours12, 1, 12, (value) => value.clockHourOfHalfDay, (bucket, value) => bucket.Time.Hours12 = value),
    'H': SteppedPatternBuilder.handlePaddedField<ZonedDateTime, ZonedDateTimeParseBucket>(
        2, PatternFields.hours24, 0, 24, (value) => value.hour, (bucket, value) => bucket.Time.Hours24 = value),
    'm': SteppedPatternBuilder.handlePaddedField<ZonedDateTime, ZonedDateTimeParseBucket>(
        2, PatternFields.minutes, 0, 59, (value) => value.minute, (bucket, value) => bucket.Time.Minutes = value),
    's': SteppedPatternBuilder.handlePaddedField<ZonedDateTime, ZonedDateTimeParseBucket>(
        2, PatternFields.seconds, 0, 59, (value) => value.second, (bucket, value) => bucket.Time.Seconds = value),
    'f': TimePatternHelper.createFractionHandler<ZonedDateTime, ZonedDateTimeParseBucket>(
        9, (value) => value.nanosecondOfSecond, (bucket, value) => bucket.Time.FractionalSeconds = value),
    'F': TimePatternHelper.createFractionHandler<ZonedDateTime, ZonedDateTimeParseBucket>(
        9, (value) => value.nanosecondOfSecond, (bucket, value) => bucket.Time.FractionalSeconds = value),
    't': TimePatternHelper.createAmPmHandler<ZonedDateTime, ZonedDateTimeParseBucket>((time) => time.hour, (bucket, value) => bucket.Time.AmPm = value),
    'c': DatePatternHelper.createCalendarHandler<ZonedDateTime, ZonedDateTimeParseBucket>((value) => value.localDateTime.calendar, (bucket, value) =>
    bucket.Date.Calendar = value),
    'g': DatePatternHelper.createEraHandler<ZonedDateTime, ZonedDateTimeParseBucket>((value) => value.era, (bucket) => bucket.Date),
    'z': HandleZone,
    'x': HandleZoneAbbreviation,
    'o': HandleOffset,
    'l': (cursor, builder) => builder.addEmbeddedLocalPartial(
        cursor, (bucket) => bucket.Date, (bucket) => bucket.Time, (value) => value.date, (value) => value.timeOfDay, (value) => value.localDateTime),
  };

  @internal ZonedDateTimePatternParser(this.templateValue, this.resolver, this.zoneProvider);

  // Note: public to implement the interface. It does no harm, and it's simpler than using explicit
  // interface implementation.
  IPattern<ZonedDateTime> parsePattern(String patternText, TimeMachineFormatInfo formatInfo) {
    // Nullity check is performed in ZonedDateTimePattern.
    if (patternText.length == 0) {
      throw new InvalidPatternError(TextErrorMessages.FormatStringEmpty);
    }

    // Handle standard patterns
    if (patternText.length == 1) {
      switch (patternText[0]) {
        case 'G':
          return ZonedDateTimePatterns.GeneralFormatOnlyPatternImpl
              .WithZoneProvider(zoneProvider)
              .WithResolver(resolver);
        case 'F':
          return ZonedDateTimePatterns.ExtendedFormatOnlyPatternImpl
              .WithZoneProvider(zoneProvider)
              .WithResolver(resolver);
        default:
          throw new InvalidPatternError.format(TextErrorMessages.UnknownStandardFormat, [patternText[0], 'ZonedDateTime']);
      }
    }

    var patternBuilder = new SteppedPatternBuilder<ZonedDateTime, ZonedDateTimeParseBucket>(formatInfo,
            () => new ZonedDateTimeParseBucket(templateValue, resolver, zoneProvider));
    if (zoneProvider == null || resolver == null) {
      patternBuilder.setFormatOnly();
    }
    patternBuilder.parseCustomPattern(patternText, PatternCharacterHandlers);
    patternBuilder.validateUsedFields();
    return patternBuilder.build(templateValue);
  }

  @private static void HandleZone(PatternCursor pattern,
      SteppedPatternBuilder<ZonedDateTime, ZonedDateTimeParseBucket> builder) {
    builder.addField(PatternFields.zone, pattern.Current);
    builder.addParseAction(ParseZone);
    builder.addFormatAction((value, sb) => sb.write(value.zone.id));
  }

  @private static void HandleZoneAbbreviation(PatternCursor pattern,
      SteppedPatternBuilder<ZonedDateTime, ZonedDateTimeParseBucket> builder) {
    builder.addField(PatternFields.zoneAbbreviation, pattern.Current);
    builder.setFormatOnly();
    builder.addFormatAction((value, sb) =>
        sb.write(value
            .getZoneInterval()
            .name));
  }

  @private static void HandleOffset(PatternCursor pattern,
      SteppedPatternBuilder<ZonedDateTime, ZonedDateTimeParseBucket> builder) {
    builder.addField(PatternFields.embeddedOffset, pattern.Current);
    String embeddedPattern = pattern.getEmbeddedPattern();
    var offsetPattern = OffsetPattern
        .Create(embeddedPattern, builder.formatInfo)
        .UnderlyingPattern;
    builder.addEmbeddedPattern(offsetPattern, (bucket, offset) => bucket.offset = offset, (zdt) => zdt.offset);
  }

  @private static ParseResult<ZonedDateTime> ParseZone(ValueCursor value, ZonedDateTimeParseBucket bucket) => bucket.ParseZone(value);
}

@private /*sealed*/ class ZonedDateTimeParseBucket extends ParseBucket<ZonedDateTime> {
  @internal final /*LocalDatePatternParser.*/LocalDateParseBucket Date;
  @internal final /*LocalTimePatternParser.*/LocalTimeParseBucket Time;
  @private DateTimeZone Zone;
  @internal Offset offset;
  @private final ZoneLocalMappingResolver resolver;
  @private final IDateTimeZoneProvider zoneProvider;

  @internal ZonedDateTimeParseBucket(ZonedDateTime templateValue, this.resolver, this.zoneProvider)
      : Date = new /*LocalDatePatternParser.*/LocalDateParseBucket(templateValue.date),
        Time = new /*LocalTimePatternParser.*/LocalTimeParseBucket(templateValue.timeOfDay),
        Zone = templateValue.zone;


  @internal ParseResult<ZonedDateTime> ParseZone(ValueCursor value) {
    DateTimeZone zone = TryParseFixedZone(value) ?? TryParseProviderZone(value);

    if (zone == null) {
      return ParseResult.NoMatchingZoneId<ZonedDateTime>(value);
    }
    Zone = zone;
    return null;
  }

  /// Attempts to parse a fixed time zone from "UTC" with an optional
  /// offset, expressed as +HH, +HH:mm, +HH:mm:ss or +HH:mm:ss.fff - i.e. the
  /// general format. If it manages, it will move the cursor and return the
  /// zone. Otherwise, it will return null and the cursor will remain where
  /// it was.
  @private DateTimeZone TryParseFixedZone(ValueCursor value) {
    if (value.CompareOrdinal(DateTimeZone.utcId) != 0) {
      return null;
    }
    value.Move(value.Index + 3);
    var pattern = OffsetPattern.GeneralInvariant.UnderlyingPattern;
    var parseResult = pattern.parsePartial(value);
    return parseResult.Success ? new DateTimeZone.forOffset(parseResult.Value) : DateTimeZone.utc;
  }

  /// Tries to parse a time zone ID from the provider. Returns the zone
  /// on success (after moving the cursor to the end of the ID) or null on failure
  /// (leaving the cursor where it was).
  @private DateTimeZone TryParseProviderZone(ValueCursor value) {
    // The IDs from the provider are guaranteed to be in order (using ordinal comparisons).
    // Use a binary search to find a match, then make sure it's the longest possible match.
    var ids = zoneProvider.ids;
    int lowerBound = 0; // Inclusive
    int upperBound = ids.length; // Exclusive
    while (lowerBound < upperBound) {
      int guess = (lowerBound + upperBound) ~/ 2;
      int result = value.CompareOrdinal(ids[guess]);
      if (result < 0) {
        // Guess is later than our text: lower the upper bound
        upperBound = guess;
      }
      else if (result > 0) {
        // Guess is earlier than our text: raise the lower bound
        lowerBound = guess + 1;
      }
      else {
// We've found a match! But it may not be as long as it
// could be. Keep track of a "longest match so far" (starting with the match we've found),
// and keep looking through the IDs until we find an ID which doesn't start with that "longest
// match so far", at which point we know we're done.
//
// We can't just look through all the IDs from "guess" to "lowerBound" and stop when we hit
// a non-match against "value", because of situations like this:
// value=Etc/GMT-12
// guess=Etc/GMT-1
// IDs includes { Etc/GMT-1, Etc/GMT-10, Etc/GMT-11, Etc/GMT-12, Etc/GMT-13 }
// We can't stop when we hit Etc/GMT-10, because otherwise we won't find Etc/GMT-12.
// We *can* stop when we get to Etc/GMT-13, because by then our longest match so far will
// be Etc/GMT-12, and we know that anything beyond Etc/GMT-13 won't match that.
// We can also stop when we hit upperBound, without any more comparisons.

        String longestSoFar = ids[guess];
        for (int i = guess + 1; i < upperBound; i++) {
          String candidate = ids[i];
          if (candidate.length < longestSoFar.length) {
            break;
          }
          if (stringOrdinalCompare(longestSoFar, 0, candidate, 0, longestSoFar.length) != 0) {
            break;
          }
          if (value.CompareOrdinal(candidate) == 0) {
            longestSoFar = candidate;
          }
        }
        value.Move(value.Index + longestSoFar.length);
        return zoneProvider.getDateTimeZoneSync(longestSoFar); // [longestSoFar];
      }
    }
    return null;
  }

  @internal
  @override
  ParseResult<ZonedDateTime> CalculateValue(PatternFields usedFields, String text) {
    var localResult = /*LocalDateTimePatternParser.*/LocalDateTimeParseBucket.CombineBuckets(usedFields, Date, Time, text);
    if (!localResult.Success) {
      return localResult.ConvertError<ZonedDateTime>();
    }

    var localDateTime = localResult.Value;

    // No offset - so just use the resolver
    if ((usedFields & PatternFields.embeddedOffset).value == 0) {
      try {
        return ParseResult.ForValue<ZonedDateTime>(Zone.resolveLocal(localDateTime, resolver));
      }
      on SkippedTimeError {
        return ParseResult.SkippedLocalTime<ZonedDateTime>(text);
      }
      on AmbiguousTimeError {
        return ParseResult.AmbiguousLocalTime<ZonedDateTime>(text);
      }
    }

    // We were given an offset, so we can resolve and validate using that
    var mapping = Zone.mapLocal(localDateTime);
    ZonedDateTime result;
    switch (mapping.Count) {
      // If the local time was skipped, the offset has to be invalid.
      case 0:
        return ParseResult.InvalidOffset<ZonedDateTime>(text);
      case 1:
        result = mapping.First(); // We'll validate in a minute
        break;
      case 2:
        result = mapping
            .First()
            .offset == offset ? mapping.First() : mapping.Last();
        break;
      default:
        throw new /*InvalidOperationException*/ StateError("Mapping has count outside range 0-2; should not happen.");
    }
    if (result.offset != offset) {
      return ParseResult.InvalidOffset<ZonedDateTime>(text);
    }
    return ParseResult.ForValue<ZonedDateTime>(result);
  }
}

