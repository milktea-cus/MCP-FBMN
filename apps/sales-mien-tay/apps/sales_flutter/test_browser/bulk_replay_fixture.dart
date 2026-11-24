// The browser CI copies offline_browser_test.dart into test/, where the
// shared implementation is already present. This export keeps analysis of the
// original test_browser/ file valid without duplicating the fixture.
export '../test/bulk_replay_fixture.dart';
