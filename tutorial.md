# Building A GraphQL API In Rails

Here at RevUnit we build a lot of web and mobile apps for our clients. When we’re going to build a JSON API, we typically reach for REST to solve the problem, which has served us well for a long time. However, there are many problems that are presented by using a RESTful API. These are just a few of the pain points we’ve experienced:

* There are many different endpoints for each operation making it difficult to remember where to go to get certain things
* Versioning can be a major pain, especially when dealing with mobile apps where we have no control over what version of the app someone may be running
* Any time the front-end devs need some new piece of information, they have to tell the back-end devs and work with them to figure out if this should be returned in an existing endpoint or a new one
* An endpoint can oftentimes either return more or less than what the front-end needs for a particular action
* Documentation is both a necessity and a major maintenance problem. The front-end devs need visibility into what the response will look like for each endpoint and what they need to provide, but especially when we are “iterating often” (part of the RevUnit mantra), it can be difficult to maintain the documentation

Recently I got a chance to evaluate GraphQL as an alternative for a new project that we had come in the door. Those of us on the project fell in love with it and have fully adopted it. It solves many of the problems we were experiencing with REST:

* There’s only one endpoint which provides access to a set of fields and objects on which to query
* There’s no need to version your API
* If the front-end devs need something that’s not already exposed by the GraphQL schema, the back-end devs simply add a new field to the schema that represents that piece of data
* In GraphQL, the front-end asks for what they need and get that back - no more and no less
* GraphQL is self-documenting and provides introspection capabilities to see what the schema looks like. The returned data is going to be a one-to-one mapping of your query

If you don't know much about GraphQL or how it works (eg. GraphQL object types, fields, arguments, etc), I highly recommend reading through the [documentation on graphql.org](http://graphql.org/learn/) before going any further. It is not a necessity before following this tutorial but it would certainly be very helpful to understanding what is going on.

### Let’s Build An API

For this tutorial, we'll build a GraphQL API for a blog. Our blog will have posts, users, and comments.

Let’s start with a fresh rails project.

`$ rails new blog-graphql-api`

Next we'll do some basic setup for our data models. First we'll generate some models.

```
$ rails generate model Post title:text body:text user_id:integer
$ rails generate model User first_name:text last_name:text bio:text
$ rails generate model Comment body:text user_id:integer post_id:integer
```

We never created our database, so let's go ahead and do that and then run our migrations.

`$ rails db:create && rails db:migrate`

So now we should have our three models which look like this:

```
# models/post.rb

class Post < ApplicationRecord
  # we set this to required: false so that while we're testing we don't have to worry about users
  belongs_to :user, required: false
  has_many :comments
end

# models/user.rb

class User < ApplicationRecord
  has_many :comments
  has_many :posts
end

# models/comment.rb

class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :post
end
```

Great, we've got our initial setup!


### GraphQL Ruby

The ruby community was one of the first to adopt the GraphQL spec and write a library for it. The graphql-ruby gem is fantastic and will do a lot of the heavy-lifting for us. Let's add it to our gemfile and install it.

```
# Gemfile

gem 'graphql'

$ bundle install
$ rails generate graphql:install
```

That generate command is going to create some boilerplate for us, including our GraphQL endpoint, controller code, and a graphql directory that contains our schema and some other defaults. You may have noticed that it also automatically added graphiql-rails to your Gemfile. This is a special editor that we will be using to run our queries in.

Before we dive in and start making any changes, let’s take a look at the setup we’ve got. First of all, we've got some controller code in `app/controllers/graphql_controller.rb`. This is just some basic code that will essentially grab the query we send it along with any query variables, and pass it along to our schema. There's also a `POST` route that has been added to our `routes.rb` file.

The rest of the relevant code is located under `app/graphql`. Our schema is at `app/graphql/blog_graphql_api_schema.rb`. Open this file up and you should see something that looks like this:

```
BlogGraphqlApiSchema = GraphQL::Schema.define do
  query(Types::QueryType)
end
```

This is the entry point to our schema definition. Right now, all it really does is tell GraphQL where our root query type is located (`Types::QueryType`).

### Our First GraphQL Field

The first thing we're going to do is add the ability to get back a blog post. Typically in REST, we would accomplish this by creating a `PostController` with an action called `show` that takes an `id` and we'd end up with a url that looked something like: `localhost:3000/posts/1`, and we would then make some decisions as to what to return to the client. With GraphQL however, we accomplish this using fields, objects, and arguments, and we don't have to worry about what payload we are going to return to the client _at all_.

On to the code! In order to be able to query for the blog post, we need to create a GraphQL Object Type which will represent our data and what we want the client to have access to. Create a new file at `app/graphql/types/post_type.rb`, and drop the following code in:

```
Types::PostType = GraphQL::ObjectType.define do
  name 'PostType'
  description 'Represents a blog post in the system'

  field :id, !types.ID, 'The ID of the blog post'
  field :title, types.String, 'A user-friendly title for the blog post'
  field :body, types.String, 'The main body of content for the blog post'
end
```

There's a lot happening here, so let's break it down one line at a time.

`Types::PostType = GraphQL::ObjectType.define do`

Here we are defining our new GraphQL Object Type. We give it the name `Types::PostType` and then open up a block where we will specify what this object looks like.

`name 'PostType'`

This line allows us to give our `PostType` a name for the documentation/introspection piece of our schema. Keep in mind that this must be unique.

`description 'Represents a blog post in the system'`

This line sets a description for the type. Again, this is used for documentation purposes.

`field :id, !types.ID, 'The ID of the blog post'`

Now things start to get interesting. We use the `field` method here to define  a field on our `PostType` that will contain a piece of data. In this case, it will be called `id` (as indicated by the first parameter, `:id`), and will have a type of ID as well (`!types.ID`). The use of `!` here can throw first-time GraphQL users for a loop, as it seems like this is being used to say "not types.ID". However in GraphQL, `!` has a special meaning of "this is a non-nullable field", meaning that our schema will guarantee that this field will always contain a non-null value. The third parameter we pass in is, again, a description, but this time it's for the field itself, describing what this "id" is exactly.

```
field :title, types.String, 'A user-friendly title for the blog post'
field :body, types.String, 'The main body of content for the blog post'
```

The next two lines are much the same - we've got a title and body field, and both of them are strings, but this time they can be null (notice there is no `!`). It's important to remember at this point that none of this is actually mapped directly to our `Post` class/object yet, so this code is really just setting up a structure for us that says "here's what the data is going to look like for this type of object". We still need to do one more thing before we can start to play with this and see our handy work.

Go ahead and open up the query type (`app/graphql/types/query_type`), and you should see some test code with a todo prompting the user to "remove me", which you should do. Remember, this is the base query type for our schema and will contain query type fields that we can run queries against. This is going to look pretty similar to what we did with our `PostType` with a couple of important differences. We want to add a new field that we can use to query our blog posts, so let's add that:

```
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
```

So here we've got a GraphQL Object Type that we've named 'Query' (since this is our root query type), and we've given it a field called `post`. So far this is all pretty familiar. The first difference is that when we set the return type for our new `post` field, we set it to our newly created `PostType` rather than a scalar like `ID`, `Int`, or `String`. We also see that there's another way to set our description - by passing the `description` method a value inside of the block. Which way you choose to do this is largely a matter of style choice.

Then we've got two new things we've never seen before - `argument` and `resolve`. `argument` here is what allows us to pass in a value to our field. In this case, we've got an argument called `id` that is required (`!types.ID`), and has a description. It's still very similar to the way that our `field` calls are structured.

The juicy bit here where we do the actual work of retrieving our blog post is in `resolve`. In GraphQL, we have this concept of a resolver, which handles the work of going and retrieving the data that we want to return to the client. It's sort of like your controller in REST, where you take some params and you use those to go and grab information from your database or wherever your information is stored (eg. some third party service). The `resolve` method takes a proc, and it passes three fields into that proc:

* `obj` - the object that has been resolved in a parent field. This will be `nil` here since nothing has been resolved at this point in the parent field.
* `args` - this is an object containing the arguments that have been passed in, and it functions just like a hash. You may have noticed that inside our `resolve` proc we are accessing the id argument with `args[:id]`.
* `ctx` or "context" - this one took me a little time to understand. This is another hash that contains information that persists across different fields/resolvers, and is passed down from your `GraphqlController`. This is, for example, where you could store the `current_user` object, which you could then use in your resolver like this: `ctx[:current_user]`.

Then inside of our proc, we grab our data with a fairly straightforward line: `Post.find(args[:id])`. Alright, we're finally at a place where we can see the fruits of our labor!.

### Let's Get Graph(i)QL

First let's give ourselves something to query on. Boot up `rails c` and create a post real quick:

```
Post.create(title: 'My First Post', body: 'GraphQL is pretty rad!')
```

Boot up your rails server, and head over to [localhost:3000/graphiql](localhost:3000/graphiql). This is the special GraphQL editor that I mentioned earlier that we can use to run queries against our schema. First take a look at the "Docs" tab on the far right. This is going to show us all of the documentation that has been generated for us on our schema. We can drill into `Query` and see our `post` field. Drill into that, and you'll see our description, the type that it returns (the `PostType` type we created), and the list of arguments. You can drill in all the way down to the scalar types on our `PostType`. This is incredible. You can't do this with REST! We've already got really great documentation for our service, and we didn't have to do any of the hard work to get there!

Now let's run our first query! Type this into the "console" portion (on the left) and click the "run" button up at the top. (HINT: you may be tempted to copy/paste, but I highly encourage you to actually type it in to see what happens while you're typing!):

```
{
  post(id: 1) {
    id
    title
    body
  }
}
```

And our data should come back looking like this:

```
{
  "data": {
    "post": {
      "id": "1",
      "title": "My First Post",
      "body": "GraphQL is pretty rad!"
    }
  }
}
```

This is powerful. If you typed in the code by hand, you noticed that it used the schema to make suggestions while you typed, had support for autocomplete, and even gave you a glimpse at the documentation for each thing while you were typing it out. On top of that, we were just able to tell the server exactly what we wanted and get that exact thing back in a one-to-one structure between query and response. What happens if we try to ask for something that doesn't exist?

```
# query

{
  post(id: 1) {
    id
    title
    body
    nope
  }
}

# response

{
  "errors": [
    {
      "message": "Field 'nope' doesn't exist on type 'PostType'",
      "locations": [
        {
          "line": 6,
          "column": 5
        }
      ],
      "fields": [
        "query",
        "post",
        "nope"
      ]
    }
  ]
}
```

GraphQL handles it for us, telling us that the field `nope` doesn't exist, and even where it's located in our query (line 6). We defined what our data looks like and we get all of this extra stuff for free. There's no hard work figuring out what a specific endpoint should respond with, no need to work really hard to keep documentation in sync with the code, and discovery can happen simply by pulling up graphiql and looking through the docs and running queries.

### Adding A Custom Field To `PostType`

So far all of the fields in `PostType` are methods/columns on our `Post` class. What happens if we need a field for our `PostType` that's _not_ a method on `Post`? For example, let's say we need to get a `shortBody` that is only a small portion of the body. How would we achieve this?

Using `resolve` of course! Let's add `shortBody` to our `PostType` real quick to see it in action:

```
# app/graphql/types/post_type.rb

# ...
field :shortBody, types.String, 'A shortened version of the body' do
  resolve ->(obj, args, ctx) {
    obj.body[0, 5]
  }
end
# ...
```

What we're doing here is adding a new field called `shortBody` to our `PostType` and giving it a `resolve` proc that takes the `obj` passed to it (which would be the `Post` that we resolve in our `posts` field in `QueryType`), calls the `body` method, and then gets the first 5 characters of the body. Give it a try!

```
{
  post(id: 1) {
    body
    shortBody
  }
}

# response

{
  "data": {
    "post": {
      "body": "GraphQL is pretty rad!",
      "shortBody": "Graph"
    }
  }
}
```

Awesome!

### Getting A List Of Posts

This is great, but normally we need to be able to show lists of things. Most blogging sites show a list of blogs, not just one at a time. How do we accomplish this? Simple! We create another field that returns an array of `PostType`'s which is designated by using `types[]` and then call `Post.all` in our resolver:

```
field :posts, types[Types::PostType] do
  description 'Retrieve a list of all blog posts'
  
  resolve ->(obj, args, ctx) {
    Post.all
  }
end
```

Now we can generate some seed data using the fantastic [Faker gem](https://github.com/stympy/faker) so we have a bunch of blog posts (run this in the rails console or stick it in your `seeds.rb` file and run `rails db:seed`):

```
100.times { Post.create(title: Faker::Lorem.words(rand(1..8)).join(' '), body: Faker::Lorem.paragraphs) }
```

Now we can run a query to get a list of these:

```
{
  posts {
    id
    title
    body
  }
}
```

Pretty quick and easy, huh? At this point you might be wondering about pagination, maybe using some arguments that you can pass into `posts` to get a subset of the results. I'm not going to delve into it here, but the best practices way to do this in GraphQL is using a concept called `connections` which graphql-ruby has first-class support for. If you're interested, [check out the documentation](http://graphql-ruby.org/relay/connections.html)! Note that you can safely ignore the fact that it talks about Relay here - Relay is not required in order to implement connections.

### Plugging In Users And Comments

Relationships are easy to express in GraphQL as well. To start with, we're going to need to have some seed data for users and comments, and we will want to tie those back to posts. Here's the script I used to do that:

```
10.times { User.create(first_name: Faker::Name.first_name, last_name: Faker::Name.last_name, bio: Faker::Lorem.paragraph) }

users = User.all

Post.all.each do |post|
  post.update(user: users.sample)

  5.times { post.comments << Comment.new(body: Faker::Lorem.paragraph, user: users.sample) }
end
```

We'll start with adding the `user` to our `PostType`. First we need to create a `UserType` to represent our `User` model. We want to expose the user's name fields and bio. Your resulting code should look something like this:

```
# app/graphql/types/user_type.rb
Types::UserType = GraphQL::ObjectType.define do
  name 'UserType'
  description 'Represents a user model'

  field :id, types.ID, 'The unique ID of the user'
  field :firstName, types.String, 'The first name of the user', property: :first_name
  field :lastName, types.String, 'The last name of the user', property: :last_name
  field :bio, types.String, 'A bio for the user giving some details about them'
end
```

Again we see mostly the same thing we've been seeing, with one new thing added - what is this `property` option? You'll notice that the field names are camelCased. This is because that is the name we expose to the client on the front-end, and front-end standards tend to dictate camelCase, whereas the ruby standard is to use snake_case. In order to maintain this, we make the field name camelCase, and then we tell graphql-ruby what the actual name of the method is that we want to call in order to resolve this field by passing it to `property`. So when we say `field :firstName, types.String, 'The first name of the user', property: :first_name`, we're saying "the client should see this as `firstName`, and GraphQL should call `user.first_name` to get the correct value".

We've got our `UserType`, but we're not using it anywhere yet! Let's plug it into our `PostType` by adding `field :user, Types::UserType, 'The user who wrote the blog post'`. Now we can query on `posts` and see our users coming back in the request:

```
{
  posts {
    user {
      id
      firstName
      lastName
      bio
    }
  }
}
```

And what of comments? We'll follow the same pattern there as well:

```
# app/graphql/types/comment_type.rb

Types::CommentType = GraphQL::ObjectType.define do
  name 'CommentType'
  description 'Represents a comment on a blog post'

  field :id, types.ID, 'The ID of the comment'
  field :body, types.String, 'The content/body for the comment'
  field :user, Types::UserType, 'The user who made the comment'
  field :post, Types::PostType, 'The post that the comment was made on'
end
```

Add the comments field to both our `PostType` and `UserType`:

```
# app/graphql/types/post_type.rb

field :comments, types[Types::CommentType], 'Comments that have been posted to the blog post'

# app/graphql/types/user_type.rb

field :posts, types[Types::PostType], 'A list of blog posts by the user'
field :comments, types[Types::CommentType], 'A list of comments posted by this user'
```

And now we can construct queries to get all kinds of neat information:

```
{
  posts {
    user {
      id
      firstName
      lastName
      bio
      posts {
        id
        title
      }
    }
    comments {
      body
      user {
        firstName
      }
    }
  }
}
```

If you run that query and look at the logs, you may notice something: N+1 queries. You'll want to make sure you're mitigating the risk of these and thinking about how queries could be constructed to cause this to happen. Make sure you're including things as you need to in your resolvers.

### Creating A Post

We've explored how we can retrieve data through our GraphQL API, but what if we wanted to be able to create a post? How would we go about that?

The answer is **mutations**.

Mutations are a root type that allows us to _perform queries that have consequences_. Let's get started with the code we will need to create a new post.

Start by adding a new file where our mutations will live at `graphql/mutations/mutation_type.rb`:

```
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
```

We've seen all of this before - an object with fields, and a field that has a description, arguments, and a resolve proc. The main difference is that in our `resolve` proc, we create data rather than just retrieving it. Now we need to plug our new `MutationType` into our schema. Open up `graphql/blog_graphql_api_schema.rb` and `mutation(Mutations::MutationType)` so that it looks like this:

```
BlogGraphqlApiSchema = GraphQL::Schema.define do
  query(Types::QueryType)
  mutation(Mutations::MutationType)
end
```

If you head back to GraphiQL and refresh the page, you should see that we now have the ability to drill in and look at our mutations now, not just queries. Here's how we can run our mutation, which should create a post and return the data back for that post that we request:

```
mutation {
  createPost(title: "Mutation", body: "My first mutation was successful!") {
    id
    title
    body
  }
}

# response

{
  "data": {
    "createPost": {
      "id": "102",
      "title": "Mutation",
      "body": "My first mutation was successful!"
    }
  }
}
```

And it works! This query does look a little different - we have to preface it with the keyword `mutation` which just tells GraphQL that it should look under `mutation` in the schema to find our fields inside of the query, and then we can call our `createPost` field with the required arguments, and ask for what we want back. We would do something similar for `update` and `delete`. Feel free to implement that and play around with the code to see what else you can do!

### Conclusion

There are a lot of things that I didn't cover here - from connections to input types, to using resolver classes and using `GraphQL::Function` to dry up code. Here's a list of some of the cool things I've used to accomplish some really neat things in the `graphql-ruby` gem:
 
 * [Field instrumentation](http://graphql-ruby.org/fields/instrumentation.html) and [custom metadata keys](http://graphql-ruby.org/schema/extending_the_dsl.html) for powerful schema manipulation. This can be used to have a DSL that looks something like `field :secretField, types.String, 'A secret field that only admins can see', permissions: :admin` in order to only allow people with permission to see that particular field and query on it. (see also [Limiting Visibility](http://graphql-ruby.org/schema/limiting_visibility.html))
 * Extracting complex `resolve` procs out into their own `Resolver` classes for better testability and cleaner code
 * [GraphQL::Function](http://graphql-ruby.org/fields/function.html) for cleaning up the schema type and drying up repetitive field declarations
 
 
It's clear from this simple tutorial however just how powerful GraphQL is, and how quickly we can get a lot of really cool functionality with very little code. This is much more powerful than REST and solves many of the problems experienced with REST. We have really been enjoying the benefits of GraphQL and hope that you will as well!
 
The code for this tutorial is [available on GitHub](https://github.com/mengledowl/blog-graphql-api), so feel free to take a look if you get stuck!