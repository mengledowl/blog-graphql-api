class Post < ApplicationRecord
  # we set this to required: false so that while we're testing we don't have to worry about users
  belongs_to :user, required: false
end
