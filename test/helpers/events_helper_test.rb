require 'test_helper'

class EventsHelperTest < ActionView::TestCase

  test "is_valid_condensor_uri: valid" do
    assert is_valid_condensor_uri( [{'class'  => "Place"}] )
  end

  test "is_valid_condensor_uri: invalid condenser uri" do
    assert !is_valid_condensor_uri("[\"Name\",\"Place\"]")
  end

end
