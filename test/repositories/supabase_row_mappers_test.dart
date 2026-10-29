import 'package:flutter_test/flutter_test.dart';
import 'package:guimavent/models/registration.dart';
import 'package:guimavent/repositories/supabase_row_mappers.dart';

void main() {
  final eventRow = {
    'event_id': 10,
    'event_name': 'Manggahan Festival',
    'description': "The official provincial festival of Guimaras.",
    'municipality_id': 1,
    'start_date': '2026-05-16',
    'end_date': '2026-05-22',
    'banner_image_url': 'https://picsum.photos/800/400?1',
    'created_by_user_id': 3,
    'status': 'active',
    'municipality': {'municipality_name': 'Jordan'},
  };

  final activityRow = {
    'subactivity_id': 14,
    'event_id': 10,
    'venue_id': 2,
    'day_number': 1,
    'activity_name': 'Opening Ceremony',
    'description': 'Official opening ceremony of the Manggahan Festival.',
    'start_time': '2026-05-16T08:00:00',
    'end_time': '2026-05-16T10:00:00',
    'event': {'banner_image_url': 'https://picsum.photos/800/400?1'},
    'venue': {
      'venue_name': 'Provincial Capitol Grounds',
      'latitude': 10.5925,
      'longitude': 122.5968,
    },
  };

  group('eventFromRow', () {
    test('maps a fully-joined row to an Event', () {
      final event = eventFromRow(eventRow);
      expect(event.id, '10');
      expect(event.name, 'Manggahan Festival');
      expect(event.startDate, DateTime.parse('2026-05-16'));
      expect(event.endDate, DateTime.parse('2026-05-22'));
      expect(event.municipality, 'Jordan');
      expect(event.coverImageUrl, 'https://picsum.photos/800/400?1');
      expect(event.isPopular, isTrue); // status == 'active'
      expect(event.description, contains('provincial festival'));
      expect(event.itinerary, isEmpty);
    });

    test('falls back to an empty municipality when the join is missing', () {
      final row = Map<String, dynamic>.from(eventRow)..remove('municipality');
      expect(eventFromRow(row).municipality, '');
    });

    test('isPopular is false for a non-active status', () {
      final row = {...eventRow, 'status': 'inactive'};
      expect(eventFromRow(row).isPopular, isFalse);
    });

    test('carries through an explicit itinerary', () {
      final event = eventFromRow(eventRow, itinerary: const []);
      expect(event.itinerary, isEmpty);
    });
  });

  group('activityFromRow', () {
    test('maps a fully-joined row to an Activity, formatting times', () {
      final activity = activityFromRow(activityRow);
      expect(activity.id, '14');
      expect(activity.eventId, '10');
      expect(activity.title, 'Opening Ceremony');
      expect(activity.activityDate, DateTime.parse('2026-05-16T08:00:00'));
      expect(activity.startTime, '8:00 AM');
      expect(activity.endTime, '10:00 AM');
      expect(activity.venue, 'Provincial Capitol Grounds');
      expect(activity.imageUrl, 'https://picsum.photos/800/400?1');
      expect(activity.latitude, 10.5925);
      expect(activity.longitude, 122.5968);
    });

    test('falls back to empty venue/image/null coordinates when those joins are missing', () {
      final row = Map<String, dynamic>.from(activityRow)
        ..remove('venue')
        ..remove('event');
      final activity = activityFromRow(row);
      expect(activity.venue, '');
      expect(activity.imageUrl, '');
      expect(activity.latitude, isNull);
      expect(activity.longitude, isNull);
    });

    test('formats afternoon/midnight/noon times correctly', () {
      final row = {
        ...activityRow,
        'start_time': '2026-05-16T00:00:00',
        'end_time': '2026-05-16T12:30:00',
      };
      final activity = activityFromRow(row);
      expect(activity.startTime, '12:00 AM');
      expect(activity.endTime, '12:30 PM');
    });
  });

  group('itineraryEntryFromRow', () {
    test('prefers the joined sub_activity over the row\'s own thin columns', () {
      final row = {
        'id': 5,
        'user_id': 'uuid-abc',
        'event_id': 10,
        'subactivity_id': 14,
        'title': 'Stale Title',
        'venue': 'Stale Venue',
        'event_date': '2026-05-16',
        'created_at': '2026-08-01T00:00:00Z',
        'sub_activity': activityRow,
      };
      final entry = itineraryEntryFromRow(row);
      expect(entry, isNotNull);
      expect(entry!.activityId, '14');
      expect(entry.activity.title, 'Opening Ceremony');
      expect(entry.activity.venue, 'Provincial Capitol Grounds');
      expect(entry.date, DateTime.parse('2026-05-16'));
      expect(entry.addedAt, DateTime.parse('2026-08-01T00:00:00Z'));
    });

    test('returns null when sub_activity is missing (unresolvable activity)', () {
      final row = {
        'id': 6,
        'user_id': 'uuid-abc',
        'event_id': null,
        'subactivity_id': null,
        'title': 'Custom Activity',
        'venue': 'My Own Venue',
        'event_date': '2026-05-17',
        'created_at': '2026-08-01T00:00:00Z',
        'sub_activity': null,
      };
      // A row with no linked sub_activity (e.g. a stale row from the legacy
      // event-level write path) can't be resolved to a real, navigable
      // Activity — skipped rather than shown as a broken entry.
      expect(itineraryEntryFromRow(row), isNull);
    });

    test(
      'regression: a "<date> - <date>" range in event_date no longer '
      'crashes the row (was: FormatException on live data)',
      () {
        final row = {
          'id': 7,
          'user_id': 'uuid-abc',
          'event_id': 10,
          'subactivity_id': 14,
          'title': 'Manggahan Festival',
          'venue': '',
          'event_date': '2026-05-16 - 2026-05-22',
          'created_at': '2026-08-01T00:00:00Z',
          'sub_activity': activityRow,
        };
        final entry = itineraryEntryFromRow(row);
        expect(entry, isNotNull);
        expect(entry!.date, DateTime.parse('2026-05-16')); // first date used
      },
    );
  });

  group('parseFlexibleDate', () {
    test('parses a real single date normally', () {
      expect(parseFlexibleDate('2026-05-16'), DateTime.parse('2026-05-16'));
    });

    test('uses the first date when given a "<date> - <date>" range', () {
      expect(
        parseFlexibleDate('2026-05-16 - 2026-05-22'),
        DateTime.parse('2026-05-16'),
      );
    });

    test('still throws on genuinely unparseable input', () {
      expect(() => parseFlexibleDate('not a date'), throwsFormatException);
    });
  });

  group('generatePassCode', () {
    test('always matches GV-2025-###### with 6 digits', () {
      final pattern = RegExp(r'^GV-2025-\d{6}$');
      for (var i = 0; i < 50; i++) {
        expect(generatePassCode(), matches(pattern));
      }
    });
  });

  group('calculateAge', () {
    test('birthday already happened this year', () {
      expect(
        calculateAge(DateTime(2000, 5, 20), now: DateTime(2026, 5, 21)),
        26,
      );
    });

    test('birthday is exactly today', () {
      expect(
        calculateAge(DateTime(2000, 5, 20), now: DateTime(2026, 5, 20)),
        26,
      );
    });

    test('birthday has not happened yet this year', () {
      expect(
        calculateAge(DateTime(2000, 5, 20), now: DateTime(2026, 5, 19)),
        25,
      );
    });
  });

  group('formatDateForSupabase', () {
    test('formats as YYYY-MM-DD, zero-padded', () {
      expect(formatDateForSupabase(DateTime(2026, 8, 6)), '2026-08-06');
      expect(formatDateForSupabase(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });

  group('registrationToArrivalCardRow', () {
    final registration = Registration(
      fullName: 'Juan Dela Cruz',
      nationality: 'Philippines',
      dateOfBirth: DateTime(2000, 5, 20),
      gender: 'Male',
      email: 'juan@example.com',
      mobileNumber: '09171234567',
      dateOfArrival: DateTime(2026, 5, 1),
      portOfEntry: 'Jordan Wharf',
      dateOfDeparture: DateTime(2026, 5, 4),
      travelingWith: 'Solo',
      purposeOfVisit: 'Leisure/Vacation',
      municipalitiesToVisit: const ['Jordan', 'Buenavista'],
    );

    test('maps every field, including derived ones, to the row shape', () {
      final row = registrationToArrivalCardRow(
        registration,
        userId: 'user-123',
        passCode: 'GV-2025-654321',
        now: DateTime(2026, 5, 1),
      );

      expect(row['user_id'], 'user-123');
      // Pre-existing thin columns.
      expect(row['full_name'], 'Juan Dela Cruz');
      expect(row['age'], 25); // birthday (May 20) hasn't happened by May 1
      expect(row['sex'], 'Male');
      expect(row['duration'], 3); // May 1 -> May 4
      expect(row['municipality'], 'Jordan'); // first of the list
      // New columns.
      expect(row['nationality'], 'Philippines');
      expect(row['date_of_birth'], '2000-05-20');
      expect(row['email'], 'juan@example.com');
      expect(row['mobile_number'], '09171234567');
      expect(row['date_of_arrival'], '2026-05-01');
      expect(row['port_of_entry'], 'Jordan Wharf');
      expect(row['date_of_departure'], '2026-05-04');
      expect(row['traveling_with'], 'Solo');
      expect(row['purpose_of_visit'], 'Leisure/Vacation');
      expect(row['municipalities_to_visit'], ['Jordan', 'Buenavista']);
      expect(row['pass_code'], 'GV-2025-654321');
      expect(row['valid_from'], '2026-05-01');
      expect(row['valid_to'], '2026-05-04');
    });

    test('municipality is null when municipalitiesToVisit is empty', () {
      final row = registrationToArrivalCardRow(
        Registration(
          fullName: registration.fullName,
          nationality: registration.nationality,
          dateOfBirth: registration.dateOfBirth,
          gender: registration.gender,
          email: registration.email,
          mobileNumber: registration.mobileNumber,
          dateOfArrival: registration.dateOfArrival,
          portOfEntry: registration.portOfEntry,
          dateOfDeparture: registration.dateOfDeparture,
          travelingWith: registration.travelingWith,
          purposeOfVisit: registration.purposeOfVisit,
          municipalitiesToVisit: const [],
        ),
        userId: 'user-123',
        passCode: 'GV-2025-654321',
      );
      expect(row['municipality'], isNull);
    });
  });

  group('userProfileFromRow', () {
    test('maps a fully-populated row, including avatar_url', () {
      final profile = userProfileFromRow({
        'id': 'user-123',
        'full_name': 'Juan Dela Cruz',
        'email': 'juan@email.com',
        'mobile_number': '0917 123 4567',
        'avatar_url': 'https://example.com/avatars/user-123/avatar.jpg',
      });
      expect(profile.fullName, 'Juan Dela Cruz');
      expect(profile.email, 'juan@email.com');
      expect(profile.mobileNumber, '0917 123 4567');
      expect(
        profile.avatarUrl,
        'https://example.com/avatars/user-123/avatar.jpg',
      );
    });

    test(
      'full_name/mobile_number fall back to empty strings, avatarUrl stays '
      'null, when absent',
      () {
        final profile = userProfileFromRow({
          'id': 'user-123',
          'email': 'juan@email.com',
        });
        expect(profile.fullName, '');
        expect(profile.mobileNumber, '');
        expect(profile.avatarUrl, isNull);
      },
    );
  });
}
