# app/services/statements/reviewer.rb
module Statements
  class Reviewer
    def self.call(statement_id:, user_name:)
      data = ApplicationController.Condenser::API.review_statement(statement_id, user_name)

      return Statements::Result.new(error: data) unless valid_response?(data)

      event = data["statements"]
      subject_uri = data["uri"]

      stat = ApplicationController.helpers.get_top_statement_to_display(event, statement_id)
      return Statements::Result.new(error: "No statement found") if stat.blank?

      key = ApplicationController.helpers.make_key(stat["label"], stat["language"])

      ApplicationController.helpers.delete_posts_belonging_statement_property(event, subject_uri, key)

      microposts = {
        subject_uri => ApplicationController.helpers.get_event_microposts(event, subject_uri)
      }

      Statements::Result.new(
        stat: stat,
        microposts: microposts,
        subject_uri: subject_uri,
        event: event
      )
    end

    def self.valid_response?(data)
      data.present? && data["statements"].present? && data["uri"].present?
    end

    private_class_method :valid_response?
  end
end