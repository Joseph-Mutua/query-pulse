class MonitorsController < ApplicationController
  before_action :set_monitor, only: %i[show edit update destroy run toggle]

  def index
    @monitors = Monitor.order_by(created_at: :desc)
  end

  def show
    @runs = @monitor.search_runs.recent_first.limit(25)
    @incidents = @monitor.incidents.active.recent_first.limit(10)
    @metrics = Metrics::Calculator.call(window: "7d", monitor: @monitor)
  end

  def new
    @monitor = Monitor.new
  end

  def edit; end

  def create
    @monitor = Monitor.new(monitor_params)
    if @monitor.save
      redirect_to @monitor, notice: "Monitor created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @monitor.update(monitor_params)
      redirect_to @monitor, notice: "Monitor updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @monitor.destroy!
    redirect_to monitors_path, notice: "Monitor deleted."
  end

  def run
    key = "manual:#{@monitor.id}:#{SecureRandom.uuid}"
    search_run = @monitor.search_runs.create!(status: "pending", engine: @monitor.engine,
                                              provider: ENV.fetch("SEARCH_PROVIDER", "fake"), idempotency_key: key)
    ProcessSearchRunJob.perform_later(search_run.id.to_s)
    redirect_to @monitor, notice: "Execution queued."
  end

  def toggle
    @monitor.update!(enabled: !@monitor.enabled?)
    redirect_to @monitor, notice: @monitor.enabled? ? "Monitor enabled." : "Monitor disabled."
  end

  private

  def set_monitor
    @monitor = Monitor.find(params[:id])
  end

  def monitor_params
    permitted = params.require(:monitor).permit(:name, :engine, :query, :location, :language, :country,
                                                :device, :frequency, :enabled, :minimum_results,
                                                :maximum_results, :maximum_response_time_ms,
                                                :required_domains, :forbidden_domains, :title_contains,
                                                :snippet_contains, :required_fields, tags: [])
    assertion_keys = %w[minimum_results maximum_results maximum_response_time_ms required_domains forbidden_domains
                        title_contains snippet_contains required_fields]
    assertions = assertion_keys.to_h do |key|
      value = permitted.delete(key)
      parsed = if %w[minimum_results maximum_results maximum_response_time_ms].include?(key)
                 value.present? ? value.to_i : nil
               else
                 value.to_s.split(",").map(&:strip).reject(&:blank?)
               end
      [key, parsed]
    end.compact_blank
    permitted.to_h.merge("assertions" => assertions)
  end
end
