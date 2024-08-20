require 'test_helper'

class StatementsHelperTest < ActionView::TestCase

  test "calendar builder" do
      #[week objects],[day objects]
    a = [ [Date.iso8601("2018-09-25T20:00:00-04:00").beginning_of_week],
          [DateTime.iso8601("2018-09-25T20:00:00-04:00"),DateTime.iso8601("2018-09-26T20:00:00-04:00")]]
    b = build_calendar '["2018-09-25T20:00:00-04:00", "2018-09-26T20:00:00-04:00"]'
    assert_equal a, b
  end

  test "calendar builder with multiple weeks" do
    #[week objects],[day objects]
    a = [ [Date.iso8601("2018-09-26T20:00:00-04:00").beginning_of_week,Date.iso8601("2018-10-26T20:00:00-04:00").beginning_of_week],
          [DateTime.iso8601("2018-09-26T20:00:00-04:00"),DateTime.iso8601("2018-10-25T20:00:00-04:00")]]
    b = build_calendar '["2018-10-25T20:00:00-04:00", "2018-09-26T20:00:00-04:00"]'
    assert_equal a, b
  end

  test "calendar builder with a week that includes a change in daylight savings" do
    #[week objects],[day objects]
    expected = [  [Date.iso8601("2018-11-02T19:00:00-04:00").beginning_of_week, Date.iso8601("2018-11-05T20:00:00-05:00").beginning_of_week, Date.iso8601("2018-11-13T19:30:00-05:00").beginning_of_week],
                  [ DateTime.iso8601("2018-11-02T19:00:00-04:00"),
                    DateTime.iso8601("2018-11-03T16:00:00-04:00"),
                    DateTime.iso8601("2018-11-03T19:00:00-04:00"),
                    DateTime.iso8601("2018-11-04T13:30:00-05:00"),
                    DateTime.iso8601("2018-11-04T16:00:00-05:00"),
                    DateTime.iso8601("2018-11-05T20:00:00-05:00"),
                    DateTime.iso8601("2018-11-13T19:30:00-05:00"),
                    DateTime.iso8601("2018-11-14T19:30:00-05:00"),
                    DateTime.iso8601("2018-11-15T19:30:00-05:00")]]
    actual = build_calendar  '[ "2018-11-02T19:00:00-04:00",
                                "2018-11-03T16:00:00-04:00",
                                "2018-11-03T19:00:00-04:00",
                                "2018-11-04T13:30:00-05:00",
                                "2018-11-04T16:00:00-05:00",
                                "2018-11-05T20:00:00-05:00",
                                "2018-11-13T19:30:00-05:00",
                                "2018-11-14T19:30:00-05:00",
                                "2018-11-15T19:30:00-05:00"]'
    assert_equal expected, actual
  end

  test "time_of_event_on_date" do
    actual = time_of_event_on_date DateTime.iso8601("2018-09-25T20:00:00-04:00"), [DateTime.iso8601("2018-09-25T20:00:00-04:00"),DateTime.iso8601("2018-09-26T20:00:00-04:00")]
    expected = ["8:00 PM"]
    assert_equal expected, actual
  end

  test "time_of_event_on_date_timezone" do
    actual = time_of_event_on_date DateTime.iso8601("2018-09-25T20:00:00-04:00"), [DateTime.iso8601("2018-09-25T20:00:00-04:00"),DateTime.iso8601("2018-09-26T20:00:00-04:00")], 'Eastern Time (US & Canada)'
    expected = ["8:00 PM"]
    assert_equal expected, actual
  end

  test "time_of_event_on_date_invalid_timezone" do
    actual = time_of_event_on_date DateTime.iso8601("2018-09-25T20:00:00-04:00"), [DateTime.iso8601("2018-09-25T20:00:00-04:00"),DateTime.iso8601("2018-09-26T20:00:00-04:00")], 'NORTHERN Time (US & Canada)'
    expected = ["8:00 PM"]
    assert_equal expected, actual
  end


  test "time_of_event_on_date_central_timezone" do
    actual = time_of_event_on_date DateTime.iso8601("2018-09-25T20:00:00-04:00"), [DateTime.iso8601("2018-09-25T20:00:00-04:00"),DateTime.iso8601("2018-09-26T20:00:00-04:00")], 'Central Time (US & Canada)'
    expected = ["7:00 PM"]
    assert_equal expected, actual
  end



  test "no_time_of_event_on_date" do
    actual = time_of_event_on_date DateTime.iso8601("2018-09-25T20:00:00-04:00"), [DateTime.iso8601("2018-09-25T00:00:00-04:00"),DateTime.iso8601("2018-09-25T00:00:00-05:00")], 'Central Time (US & Canada)'
    expected = ["Time unknown", "Time unknown"]
    assert_equal expected, actual
  end

  test "get_top_statment_to_display regular" do
    stats = JSON.parse(File.read("test/fixtures/files/chaakapesh_resource.json"))["statements"]
    actual = get_top_statment_to_display(stats, 84138)
    expected = stats["webpage_link_fr"]
    assert_equal expected, actual
  end

  test "get_top_statment_to_display alternatives" do
    stats = JSON.parse(File.read("test/fixtures/files/chaakapesh_resource.json"))["statements"]
    actual = get_top_statment_to_display(stats, 84129)
    expected = stats["title_fr"]
    assert_equal expected, actual
  end

  test "get_top_statment_to_display second alternatives" do
    stats = JSON.parse(File.read("test/fixtures/files/chaakapesh_resource.json"))["statements"]
    actual = get_top_statment_to_display(stats, 84130)
    expected = stats["title_fr"]
    assert_equal expected, actual
  end
  

  test "remove a date from a list of dates" do
    expected = ["2021-01-01"]
    actual = remove_dateTime("2021-01-02","",["2021-01-01","2021-01-02"])
    assert_equal expected, actual
  end

  test "remove a dateTime from a list of dates" do
    expected = ["2021-01-02T20:00:00-05:00"]
    actual = remove_dateTime("2021-01-01T20:00:00-05:00","",["2021-01-01T20:00:00-05:00","2021-01-02T20:00:00-05:00"])
    assert_equal expected, actual
  end

  test "remove a date with JAN-1, 8 PM from a list of dates" do
    expected = ["2021-01-02T20:00:00-05:00"]
    actual = remove_dateTime("2021-JAN-1, 8 PM","",["2021-01-01T20:00:00-05:00","2021-01-02T20:00:00-05:00"])
    assert_equal expected, actual
  end

  test "remove a date with JAN-1, unknown time from a list of dates" do
    expected = ["2021-01-02T20:00:00-05:00"]
    actual = remove_dateTime("2021-JAN-1, unknown time","",["2021-01-01T00:00:00-05:00","2021-01-02T20:00:00-05:00"])
    assert_equal expected, actual
  end

  test "remove a dateTime independant of timezone from a list of dates" do
    expected = ["2021-01-02T20:00:00-05:00"]
    actual = remove_dateTime("2021-01-02T00:00:00-01:00","",["2021-01-01T20:00:00-05:00","2021-01-02T20:00:00-05:00"])
    assert_equal expected, actual
  end

  test "remove a dateTime from a list of dates with an invalide date" do
    expected = ["2021-01-01T20:00:00-05:00"]
    actual = remove_dateTime("2021-01-02T20:00:00-05:00","",["2021-01-01T20:00:00-05:00","2021-01-02T20:00:00-05:00","error"])
    assert_equal expected, actual
  end

  test "remove a dateTime with seconds" do
    expected = []
    timezone = 'Mountain Time (US & Canada)'
    actual = remove_dateTime("2022-Jan-18, 12:00 AM",timezone,["2022-01-18T00:00:26-07:00"])
    assert_equal expected, actual
  end

  test "add US American style date using 3 letter month to existing array of dates" do
    timezone = 'Eastern Time (US & Canada)'
    expected = ["2022-06-24","2022-06-27"]
    assert_equal expected, add_dateTime("2022-Jun-27",timezone,["2022-06-24"])
  end

  test "add ISO style date to existing array of dates" do
    timezone = 'Eastern Time (US & Canada)'
    expected = ["2022-06-24","2022-06-27"]
    assert_equal expected, add_dateTime("2022-06-27",timezone,["2022-06-24"])
  end


  test "add summer dateTime in daylight savings" do
    timezone = 'Eastern Time (US & Canada)'
    expected = ["2022-06-24T10:00:00-04:00","2022-06-27T10:00:00-04:00"]
    assert_equal expected, add_dateTime("2022-Jun-27T10:00",timezone,["2022-06-24T10:00:00-04:00"])
  end

  test "add winter dateTime not in daylight savings" do
    timezone = 'Eastern Time (US & Canada)'
    expected = ["2022-01-01T10:00:00-05:00"]
    assert_equal expected, add_dateTime("2022-Jan-01T10:00",timezone,[])
  end

end
