class ExecuteMonitorJob < ApplicationJob
  queue_as :default
  retry_on Faraday::TimeoutError, Faraday::ConnectionFailed, wait: :polynomially_longer, attempts: 3
  discard_on Mongoid::Errors::DocumentNotFound

  def perform(monitor_id, idempotency_key: nil)
    monitor = Monitor.find(monitor_id)
    Search::ExecuteMonitor.call(monitor:, idempotency_key: idempotency_key || "scheduled:#{monitor_id}:#{Time.current.to_i / 60}")
  end
end
