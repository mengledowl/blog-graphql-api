BlogGraphqlApiSchema = GraphQL::Schema.define do
  query(Types::QueryType)
  mutation(Mutations::MutationType)
end
