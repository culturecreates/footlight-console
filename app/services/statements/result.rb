# app/services/statements/result.rb
module Statements
  class Result
    attr_reader :stat, :microposts, :subject_uri, :event, :error

    def initialize(stat: nil, microposts: nil, subject_uri: nil, event: nil, error: nil)
      @stat = stat
      @microposts = microposts
      @subject_uri = subject_uri
      @event = event
      @error = error
    end

    def success?
      error.nil?
    end
  end
end