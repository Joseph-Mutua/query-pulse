module Api
  module V1
    class BaseController < ActionController::API
      before_action :set_current_request

      rescue_from Mongoid::Errors::DocumentNotFound, with: :render_not_found
      rescue_from Mongoid::Errors::Validations, ActiveModel::ValidationError, with: :render_validation_error
      rescue_from ActionController::ParameterMissing, with: :render_parameter_error

      private

      def paginate(criteria)
        page = [params.fetch(:page, 1).to_i, 1].max
        per_page = params.fetch(:per_page, 25).to_i.clamp(1, 100)
        total = criteria.count
        records = criteria.skip((page - 1) * per_page).limit(per_page)
        [records, { page:, per_page:, total:, total_pages: (total.fdiv(per_page)).ceil }]
      end

      def render_error(code, message, status:, details: {})
        render json: { error: { code:, message:, details: } }, status:
      end

      def render_not_found(error)
        render_error("NOT_FOUND", "The requested resource was not found", status: :not_found,
                     details: { resource: error.klass.to_s })
      end

      def render_validation_error(error)
        record = error.respond_to?(:document) ? error.document : error.respond_to?(:model) ? error.model : nil
        details = record&.errors&.to_hash || {}
        render_error("VALIDATION_ERROR", "The resource is invalid", status: :unprocessable_content, details:)
      end

      def render_parameter_error(error)
        render_error("INVALID_REQUEST", error.message, status: :bad_request)
      end

      def set_current_request
        Current.request_id = request.request_id
      end
    end
  end
end
