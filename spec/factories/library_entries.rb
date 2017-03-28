# rubocop:disable Metrics/LineLength
# == Schema Information
#
# Table name: library_entries
#
#  id              :integer          not null, primary key
#  media_type      :string           not null, indexed => [user_id], indexed => [user_id, media_id]
#  notes           :text
#  nsfw            :boolean          default(FALSE), not null
#  private         :boolean          default(FALSE), not null, indexed
#  progress        :integer          default(0), not null
#  rating          :decimal(2, 1)
#  reconsume_count :integer          default(0), not null
#  reconsuming     :boolean          default(FALSE), not null
#  status          :integer          not null, indexed => [user_id]
#  volumes_owned   :integer          default(0), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  anime_id        :integer          indexed
#  drama_id        :integer          indexed
#  manga_id        :integer          indexed
#  media_id        :integer          not null, indexed => [user_id, media_type]
#  user_id         :integer          not null, indexed, indexed => [media_type], indexed => [media_type, media_id], indexed => [status]
#
# Indexes
#
#  index_library_entries_on_anime_id                             (anime_id)
#  index_library_entries_on_drama_id                             (drama_id)
#  index_library_entries_on_manga_id                             (manga_id)
#  index_library_entries_on_private                              (private)
#  index_library_entries_on_user_id                              (user_id)
#  index_library_entries_on_user_id_and_media_type               (user_id,media_type)
#  index_library_entries_on_user_id_and_media_type_and_media_id  (user_id,media_type,media_id) UNIQUE
#  index_library_entries_on_user_id_and_status                   (user_id,status)
#
# rubocop:enable Metrics/LineLength

FactoryGirl.define do
  factory :library_entry do
    association :media, factory: :anime, strategy: :build
    user
    status 'planned'
    progress 0

    trait :nsfw do
      association :media, :nsfw, factory: :anime, strategy: :build
    end
    trait :with_rating do
      rating { rand(1.0..10.0) / 2 }
    end
  end
end
