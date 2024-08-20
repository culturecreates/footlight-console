require 'test_helper'

class MicropostsHelperTest < ActionView::TestCase

# extract_property_from_key

  test "extract_property_from_key: simple case" do
    expected = "name"
    assert_equal expected, extract_property_from_key("name_en")
  end

  test "extract_property_from_key: no language case" do
    expected = "photo"
    assert_equal expected, extract_property_from_key("photo")
  end

  test "extract_property_from_key: double underscore case" do
    expected = "buy_link"
    assert_equal expected, extract_property_from_key("buy_link_en")
  end

  test "extract_property_from_key: no language with double underscore case" do
    expected = "start_date"
    assert_equal expected, extract_property_from_key("start_date")
  end

# extract_language_from_key

  test "extract_language_from_key: simple case" do
    expected = "en"
    assert_equal expected, extract_language_from_key("name_en")
  end

  test "extract_language_from_key: no language case" do
    expected = ""
    assert_equal expected, extract_language_from_key("photo")
  end

  test "extract_language_from_key: double underscore case" do
    expected = "en"
    assert_equal expected, extract_language_from_key("buy_link_en")
  end

  test "extract_language_from_key: no language with double underscore case" do
    expected = ""
    assert_equal expected, extract_language_from_key("start_date")
  end

end
