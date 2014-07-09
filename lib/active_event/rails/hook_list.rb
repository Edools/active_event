module ActiveEvent
  module Rails
    # Class used to hold all the events hook's paths and later sync
    # them with an event runner instance.
    #
    class HookList
      include Singleton

      # Initialize an empty hook list
      #
      def initialize
        host = ActiveEvent::Configuration.event_host
        port = ActiveEvent::Configuration.event_port
        name = ActiveEvent::Configuration.name.downcase.gsub(' ', '-').strip
        @base_service_url = "#{host}:#{port}/services/#{name}"
        @hooks = []
      end

      # Proxy all methods called in the {ActiveEvent::Hook} to
      # {ActiveEvent::Hook} instance. Just a syntax sugar.
      #
      def self.method_missing(method, *args, &block)
        instance.send(method, *args, &block)
      end

      # Clear the hook list.
      #
      def clear
        @hooks = []
      end

      # forward {<<} method to the hook list.
      #
      def <<(other)
        @hooks << other
      end

      # Register in event runner all the hooks defined in the list. If some of
      # them already exists, they will be excluded and readded.
      #
      def register
        old_hooks = get_old_hooks
        hooks_to_delete = get_hooks_to_delete(old_hooks)
        hooks_to_add = get_hooks_to_add(old_hooks)
        delete_hooks(hooks_to_delete) if hooks_to_delete.any?
        add_hooks(hooks_to_add) unless hooks_to_add.empty?
      end

      # Get the old hooks list for this service from the event-runner
      #
      def get_old_hooks

        JSON.load(RestClient.get(@base_service_url))['hooks']
      end

      # Select from old hooks those that should be deleted from event runner.
      #
      def get_hooks_to_delete(old_hooks)
        hooks_to_delete = []
        old_hooks.each do |old_hook|
          found = false
          @hooks.each do |hook|
            if hook['class'] == old_hook['class'] && old_hook['active']
              found = true
              break
            end
          end
          next if found
          hooks_to_delete << old_hook
        end
        hooks_to_delete
      end

      # Select from the hooks defined in the app those that should be created
      # in the event runner.
      #
      def get_hooks_to_add(old_hooks)
        hooks_to_add = []
        @hooks.each do |hook|
          found = false
          old_hooks.each do |old_hook|
            if hook['class'] == old_hook['class'] && old_hook['active']
              found = true
              break
            end
          end
          next if found
          hooks_to_add << hook
        end
        hooks_to_add
      end

      # Properly delete the +hooks_to_delete+ in the event runner.
      #
      def delete_hooks(hooks_to_delete)
        hooks_to_delete.each do |hook|
          RestClient.delete "#{@base_service_url}/hooks/#{hook['id']}"
        end
      end

      # # Properly creates the +hooks_to_add+ in the event runner..
      #
      def add_hooks(hooks_to_add)
        hooks_to_add.each do |hook|
          RestClient.post "#{@base_service_url}/hooks", {
            'class'=> hook['class'],
            'postPath' => ActiveEvent::Engine.routes.url_helpers.notifications_path(hook['class'].downcase),
            'active' => true
          }
        end
      end
    end
  end
end