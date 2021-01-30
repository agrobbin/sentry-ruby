if defined?(ActionCable) && ActionCable.version >= Gem::Version.new('6.0.0')
  require "spec_helper"
  require "action_cable/engine"
  require "action_cable/connection/test_case"
  require "action_cable/channel/test_case"

  # ensure we can access `connection.env` in tests like we can in production
  ActiveSupport.on_load :action_cable_channel_test_case do
    class ::ActionCable::Channel::ConnectionStub
      def env
        @_env ||= ::ActionCable::Connection::TestRequest.create.env
      end
    end
  end

  class ChatChannel < ::ActionCable::Channel::Base
    def subscribed
      raise "foo"
    end
  end

  class AppearanceChannel < ::ActionCable::Channel::Base
    def appear
      raise "foo"
    end
  end

  RSpec.describe "Sentry::Rails::ActionCable" do
    let(:transport) { Sentry.get_current_client.transport }

    before(:all) do
      make_basic_app
      ::ActionCable.server.config.cable = { "adapter" => "test" }
    end

    describe ChatChannel do
      include ActionCable::Channel::TestCase::Behavior

      tests ChatChannel

      it "captures errors during the subscribe" do
        expect { subscribe room_id: 42 }.to raise_error('foo')

        event = transport.events.last.to_json_compatible

        expect(event).to include(
          "transaction" => "ActionCable/ChatChannel#subscribed",
          "extra" => {
            "action_cable" => {
              "params" => { "room_id" => 42 }
            }
          }
        )

        expect(Sentry.get_current_scope.extra).to eq({})
      end
    end

    describe AppearanceChannel do
      include ActionCable::Channel::TestCase::Behavior

      tests AppearanceChannel

      before { subscribe room_id: 42 }

      it "captures errors during the action" do
        expect { perform :appear, foo: 'bar' }.to raise_error('foo')

        event = transport.events.last.to_json_compatible

        expect(event).to include(
          "transaction" => "ActionCable/AppearanceChannel#appear",
          "extra" => {
            "action_cable" => {
              "params" => { "room_id" => 42 },
              "data" => { "action" => "appear", "foo" => "bar" }
            }
          }
        )

        expect(Sentry.get_current_scope.extra).to eq({})
      end
    end
  end
end