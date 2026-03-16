module RequestSeparator
  def process_action(event)
    super
    Rails.logger.info("")
  end
end

ActiveSupport.on_load(:action_controller) do
  ActionController::LogSubscriber.prepend(RequestSeparator)
end
