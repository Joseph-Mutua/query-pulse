class Incident
  include Mongoid::Document

  STATUSES = %w[open acknowledged resolved].freeze
  SEVERITIES = %w[info warning critical].freeze
  TYPES = %w[
    field_added field_removed type_changed result_count_changed result_order_changed
    domain_mismatch assertion_failed latency_regression empty_results request_failure
    schema_changed browser_failure challenge_detected
  ].freeze

  belongs_to :monitor
  belongs_to :search_run

  field :incident_type, type: String
  field :severity, type: String, default: "warning"
  field :title, type: String
  field :description, type: String
  field :path, type: String
  field :previous_value
  field :current_value
  field :first_seen_at, type: Time
  field :last_seen_at, type: Time
  field :occurrence_count, type: Integer, default: 1
  field :status, type: String, default: "open"
  field :metadata, type: Hash, default: {}
  field :fingerprint, type: String

  validates :incident_type, inclusion: { in: TYPES }
  validates :severity, inclusion: { in: SEVERITIES }
  validates :status, inclusion: { in: STATUSES }
  validates :title, :fingerprint, :first_seen_at, :last_seen_at, presence: true

  index({ monitor_id: 1, status: 1, last_seen_at: -1 })
  index({ incident_type: 1, status: 1 })
  index({ monitor_id: 1, fingerprint: 1, status: 1 })

  scope :active, -> { where(:status.in => %w[open acknowledged]) }
  scope :recent_first, -> { order_by(last_seen_at: :desc) }

  def acknowledge!
    update!(status: "acknowledged")
  end

  def resolve!
    update!(status: "resolved")
  end
end
