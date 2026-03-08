class Monitor
  include Mongoid::Document
  include Mongoid::Timestamps

  FREQUENCIES = {
    "5m" => 5.minutes,
    "15m" => 15.minutes,
    "30m" => 30.minutes,
    "1h" => 1.hour,
    "6h" => 6.hours,
    "12h" => 12.hours,
    "24h" => 24.hours
  }.freeze
  ENGINES = %w[google bing fake].freeze
  DEVICES = %w[desktop mobile tablet].freeze

  field :name, type: String
  field :engine, type: String, default: "google"
  field :query, type: String
  field :location, type: String
  field :language, type: String, default: "en"
  field :country, type: String, default: "us"
  field :device, type: String, default: "desktop"
  field :frequency, type: String, default: "1h"
  field :enabled, type: Mongoid::Boolean, default: true
  field :tags, type: Array, default: []
  field :assertions, type: Hash, default: {}
  field :next_execution_at, type: Time
  field :healthy_run_streak, type: Integer, default: 0

  has_many :search_runs, dependent: :delete_all
  has_many :snapshots, dependent: :delete_all
  has_many :incidents, dependent: :delete_all

  validates :name, :query, :frequency, presence: true
  validates :engine, inclusion: { in: ENGINES }
  validates :device, inclusion: { in: DEVICES }
  validates :frequency, inclusion: { in: FREQUENCIES.keys }
  validates :language, format: { with: /\A[a-z]{2}(?:-[A-Z]{2})?\z/ }
  validates :country, format: { with: /\A[a-zA-Z]{2}\z/ }
  validates :name, length: { maximum: 120 }
  validates :query, length: { maximum: 500 }

  index({ enabled: 1, next_execution_at: 1 })
  index({ name: 1 })

  before_validation :normalize_values
  before_create :schedule_first_execution

  def due?(at = Time.current)
    enabled? && (next_execution_at.nil? || next_execution_at <= at)
  end

  def schedule_next!(from: Time.current)
    update!(next_execution_at: from + FREQUENCIES.fetch(frequency))
  end

  private

  def normalize_values
    self.engine = engine.to_s.downcase
    self.device = device.to_s.downcase
    self.country = country.to_s.downcase
    self.tags = Array(tags).filter_map { |tag| tag.to_s.strip.presence }.uniq
    self.assertions = assertions.to_h.deep_stringify_keys
  end

  def schedule_first_execution
    self.next_execution_at ||= Time.current
  end
end
