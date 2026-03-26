class PipelineRule < ApplicationRecord
  VALID_STATUSES = %w[ok warning critical].freeze

  belongs_to :website, optional: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }

  validates :name, presence: true
  validates :status, presence: true,
                     inclusion: { in: VALID_STATUSES }
  validates :diagnosis, presence: true
  validates :position, presence: true,
                       numericality: { only_integer: true }

  validate :conditions_structure

  def to_resolved_rule
    {
      name: name,
      conditions: (conditions || {}).deep_stringify_keys,
      status: status,
      diagnosis: diagnosis,
      position: position,
      source: :database
    }
  end

  private

  def conditions_structure
    normalized_conditions = conditions.is_a?(Hash) ? conditions.deep_stringify_keys : nil
    return if normalized_conditions&.[]("metric").present?

    errors.add(:conditions, "must include metric")
  end
end
