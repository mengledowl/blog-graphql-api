Types::QueryType = GraphQL::ObjectType.define do
  name "Query"

  field :post, Types::PostType do
    description 'Retrieve a blog post by id'

    argument :id, !types.ID, 'The ID of the blog post to retrieve'

    resolve ->(obj, args, ctx) {
      Post.find(args[:id])
    }
  end

  field :posts, types[Types::PostType] do
    description 'Retrieve a list of all blog posts'

    resolve ->(obj, args, ctx) {
      Post.all
    }
  end
end
