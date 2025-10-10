# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    # Standard Rails ActionCable connection.
    # Required by ActionCable even when using Turbo Streams.
  end
end
