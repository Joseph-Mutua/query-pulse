class SearchRun
  include Mongoid::Document
  include Mongoid::Timestamps::Created

  STATUSES = %w[pending running success failed timeout invalid_response].freeze

  belongs_to :monitor, class_name: "QueryPulse::Monitor", inverse_of: :search_runs
  has_one :snapshot, dependent: :delete_all

  field :started_at, type: Time
  field :completed_at, type: Time
  field :status, type: String, default: "pending"
  field :http_status, type: Integer
  field :response_time_ms, type: Integer
  field :result_count, type: Integer, default: 0
  field :engine, type: String
  field :provider, type: String
  field :raw_response, type: Hash, default: {}
  field :normalized_response, type: Hash, default: {}
  field :schema_fingerprint, type: String
  field :error_type, type: String
  field :error_message, type: String
  field :response_changes, type: Array, default: []
  field :assertion_results, type: Array, default: []
  field :relevance_score, type: Integer
  field :diagnostics, type: Hash, default: {}
  field :idempotency_key, type: String

  validates :status, inclusion: { in: STATUSES }
  validates :idempotency_key, uniqueness: true, allow_nil: true
  index({ monitor_id: 1, started_at: -1 })
  index({ status: 1, created_at: -1 })
  index({ idempotency_key: 1 }, { unique: true, sparse: true })

  scope :successful, -> { where(status: "success") }
  scope :recent_first, -> { order_by(started_at: :desc) }

  def duration_ms
    response_time_ms || if started_at && completed_at
                          ((completed_at - started_at) * 1000).round
                        end
  end
end
