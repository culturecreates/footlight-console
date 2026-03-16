module Condenser
  def self.client
    @client ||= Condenser::Client.new
  end
end