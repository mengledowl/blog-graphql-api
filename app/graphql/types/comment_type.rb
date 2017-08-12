Types::CommentType = GraphQL::ObjectType.define do
  name 'CommentType'
  description 'Represents a comment on a blog post'

  field :id, types.ID, 'The ID of the comment'
  field :body, types.String, 'The content/body for the comment'
  field :user, Types::UserType, 'The user who made the comment'
  field :post, Types::PostType, 'The post that the comment was made on'
end