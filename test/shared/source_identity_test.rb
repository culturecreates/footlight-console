require "test_helper"

class SourceIdentityTest < ActiveSupport::TestCase
  test "to_seedurl matches Website normalization output" do
    website = Website.new(url: " https://Example.com/Foo/Bar?x=1#frag ")
    website.valid?

    source_identity = SourceIdentity.from_url(" https://Example.com/Foo/Bar?x=1#frag ")

    assert_equal website.url, source_identity.to_seedurl
  end

  test "to_canonical_url keeps scheme differences for http and https" do
    http_identity = SourceIdentity.from_url("http://Example.com/path")
    https_identity = SourceIdentity.from_url("https://Example.com/path")

    assert_equal "http://example.com/path", http_identity.to_canonical_url
    assert_equal "https://example.com/path", https_identity.to_canonical_url
  end

  test "to_canonical_url normalizes trailing slash" do
    source_identity = SourceIdentity.from_url("https://Example.com")

    assert_equal "https://example.com/", source_identity.to_canonical_url
  end

  test "to_canonical_url drops fragments" do
    source_identity = SourceIdentity.from_url("https://Example.com/path#section")

    assert_equal "https://example.com/path", source_identity.to_canonical_url
  end

  test "to_canonical_url drops query params" do
    source_identity = SourceIdentity.from_url("https://Example.com/path?x=1&y=2")

    assert_equal "https://example.com/path", source_identity.to_canonical_url
  end

  test "to_wringer_key matches expected escaped canonical url" do
    url = "https://Example.com/path?x=1"

    expected = CGI.escape("https://example.com/path?x=1")

    assert_equal expected, SourceIdentity.from_url(url).to_wringer_key
  end
end
