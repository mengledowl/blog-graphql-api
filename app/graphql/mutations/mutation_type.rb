Mutations::MutationType = GraphQL::ObjectType.define do
  name 'Mutation'

  field :createPost, Types::PostType do
    description 'Allows you to create a new blog post'

    argument :title, !types.String
    argument :body, !types.String

    resolve ->(obj, args, ctx) {
      post = Post.new(args.to_h)

      post.save

      post
    }
  end
end