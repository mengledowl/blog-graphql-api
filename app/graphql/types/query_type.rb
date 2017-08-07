Types::QueryType = GraphQL::ObjectType.define do
  name "Query"

  field :post, Types::PostType do
    description 'Retrieve a blog post by id'

    argument :id, !types.ID, 'The ID of the blog post to retrieve'

    resolve ->(obj, args, ctx) {
      Post.find(args[:id])
    }
  end
end
