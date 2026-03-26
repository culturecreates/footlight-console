class EventPipelineStatus
  def self.call(event:)
    new(event).call
  end

  def initialize(event)
    @event = event
  end

  def call
    result, = PipelineBuilder.evaluate(event: event)

    {
      event_id: event.id,
      status: result[:status],
      diagnosis: result[:diagnosis]
    }
  end

  private

  attr_reader :event
end
