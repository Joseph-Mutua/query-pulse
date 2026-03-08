class Snapshot
  include Mongoid::Document

  belongs_to :monitor
  belongs_to :search_run

  field :captured_at, type: Time, default: -> { Time.current }
  field :normalized_data, type: Hash, default: {}
  field :schema, type: Hash, default: {}
  field :schema_hash, type: String
  field :content_hash, type: String

  validates :schema_hash, :content_hash, presence: true
  validates :search_run_id, uniqueness: true
  index({ monitor_id: 1, captured_at: -1 })
  index({ search_run_id: 1 }, { unique: true })
  index({ schema_hash: 1 })

  scope :recent_first, -> { order_by(captured_at: :desc) }
end
