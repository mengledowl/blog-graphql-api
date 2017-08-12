Types::UserType = GraphQL::ObjectType.define do
  name 'UserType'
  description 'Represents a user model'

  field :id, types.ID, 'The unique ID of the user'
  field :firstName, types.String, 'The first name of the user', property: :first_name
  field :lastName, types.String, 'The last name of the user', property: :last_name
  field :bio, types.String, 'A bio for the user giving some details about them'
end