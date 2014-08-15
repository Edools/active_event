module ActiveSpy
  # Controller to handle notifications request coming from an event-runner
  # instance.
  #
  class NotificationsController < ActionController::Base
    def handle
      request.format = 'application/json'
      hooks = ActiveSpy::Rails::HookList.hooks
      result = nil
      hooks.each do |hook|
        if hook['post_class'].downcase == params['class']
           handle_result(hook, params) and return
        end
      end
      render nothing: true, status: :not_found
    end

    def handle_result(hook, params)
      result = get_result(hook, params)
      ::Rails.logger.warn("[EVENT][#{hook['post_class']}] Listener result: #{result}")
      if result.is_a? Array
        handle_array_result(hook, result, params)
      else
        handle_model_result(hook, result, params)
      end
    end


    def get_result(hook, params)
      listener = "#{hook['post_class']}Listener".constantize
      result = listener.new.handle(params['event'])
    end

    def handle_model_result(hook, result, params)
      if result.errors.present?
        ::Rails.logger.warn("[EVENT][#{hook['post_class']}] Error receiving event #{params}")
        ::Rails.logger.warn("[EVENT][#{hook['post_class']}] Result errors: #{result.errors}")
        render json: result.errors
      else
        render nothing: true
      end
    end

    def handle_array_result(hook, result, params)
      model_with_errors = result.select { |m| m.errors.present? }
      if model_with_errors.any?
        ::Rails.logger.warn("[EVENT][#{hook['post_class']}] Error receiving event #{params}")
        model_with_errors.each do |model|
          ::Rails.logger.warn("[EVENT][#{hook['post_class']}] #{model} errors: #{model.errors}")
        end
      else
        render nothing: true
      end
    end
  end
end
