require 'test_helper'

class UsersProfileTest < ActionDispatch::IntegrationTest
  include ApplicationHelper

  def setup
    @admin     = users(:michael)
    @non_admin = users(:archer)
  end


  test "profile display" do
    log_in_as(@admin)
    get user_path(@admin)
    assert_template 'users/show'
    assert_select 'title', full_title(@admin.name)
    assert_select 'h1', text: "#{@admin.name} (admin role)"
    assert_match @admin.microposts.count.to_s, response.body
    assert_match "following", response.body

  
    @admin.microposts.paginate(page: 1).each do |micropost|
      assert_match micropost.content, response.body
    end
  end

  test "non_admin profile display" do
    log_in_as(@non_admin)
    get user_path(@non_admin)
    assert_template 'users/show'
    assert_select 'title', full_title(@non_admin.name)
    assert_select 'h1', text: @non_admin.name
    assert_match @non_admin.microposts.count.to_s, response.body
    assert_no_match "following", response.body
  
    @non_admin.microposts.paginate(page: 1).each do |micropost|
      assert_match micropost.content, response.body
    end
  end
end
