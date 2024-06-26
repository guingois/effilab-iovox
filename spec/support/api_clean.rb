# frozen_string_literal: true

api_cleaner = Class.new do
  class << self
    def instance
      @instance ||= new
    end

    def call
      instance.call
    end
  end

  attr_reader :client

  def initialize
    @client = Iovox::Client.new
  end

  def call
    cleaners = []
    cleaners << Thread.new { clean_nodes }
    cleaners << Thread.new { clean_contacts }
    cleaners.each(&:join)
  end

  private

  def clean_nodes
    if (nodes = client.get_nodes(query: { req_fields: 'nid' }).result)
      node_ids =
        nodes
          .select { |node| node['node_id']&.start_with?('test/') }
          .map { |node| node['node_id'] }

      client.delete_nodes(query: { node_ids: node_ids.join(',') }) unless node_ids.empty?
    end
  end

  def clean_contacts
    if (contacts = client.get_contacts(query: { req_fields: 'cid' }).result)
      contact_ids =
        contacts
          .select { |contact| contact['contact_id']&.start_with?('test/') }
          .map { |contact| contact['contact_id'] }

      unless contact_ids.empty?
        client.delete_contacts(query: { contact_ids: contact_ids.join(','), rm_rules: 'TRUE' })
      end
    end
  end
end

RSpec.configure do |config|
  config.after(:example, :api_clean) do |example|
    api_cleaner.call
  end
end
