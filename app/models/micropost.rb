class Micropost < ApplicationRecord
  belongs_to :user
  default_scope -> { order(:related_subject_uri, created_at: :desc) }
  validates :user_id, presence: true
  validates :content, presence: true

end
