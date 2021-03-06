# article editor

Created on a Mac M1 with Elixir 1.11.4 (compiled with Erlang/OTP 23), Phoenix 1.3.0, and MongoDB 4.4.4


Before starting Phoenix you need to get Elixir, Mongo and Node (`brew install node` on a Mac - you need Homebrew if you don't already have it - https://brew.sh/)

  * Install Node.js dependencies with `cd assets` then
  * `npm install`
  * `./node_modules/brunch/bin/brunch build`
  * `cd ..`
  * Install dependencies with `mix deps.get`


Run the MongoDB console
   `mongo` from a Terminal window and do this:

   `use my_app_db`

Then
   `db.article.insert({name: "Ada Lovelace", classification: "programmer",
                       _id: "ffffffffffffffffffffffff", short_id: "4444j" })`

This creates this database if it doesn't already exist   

Enter
   `show dbs`

And you should see 'my_app_db' listed

Now you can do the following
```
  db.createCollection("my_collection")
  db.createUser(
   {
    user: "root",
    pwd: "rootpassword",
    roles: [
      {
        role: "dbOwner",
        db: "my_app_db"
      }
    ]
   }
  )
```

Then, from a Terminal window,

  * Run the tests with `mix test`
  * Start Phoenix with `mix phx.server`

It should connect to Mongo using the information in mongo_db.ex:
```
def start(_type, _args) do
  import Supervisor.Spec

  children = [
    supervisor(SimpleMongoAppWeb.Endpoint, []),
    worker(
           Mongo,
           [[
             database: "my_app_db",
             hostname: "localhost",
             username: "root",
             password: "rootpassword"
           ]]
         )
  ]

  opts = [strategy: :one_for_one, name: SimpleMongoApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

You can also do this from a Terminal window   

`iex -S mix phx.server`

```
Mongo.start_link(
  name: :article,
  database: "my_app_db",
  hostname: "localhost",
  username: "root",
  password: "rootpassword"
)
```

` Mongo.insert_one(:article, "my_app_db", %{name: "John", classification: "man", _id: "decaf3c2b807174b1b6df0ff", short_id: "onYUN" }) `

` Mongo.insert_one(:article, "my_app_db", %{name: "Ferrari", classification: "car", color: "red", _id: "18b93c9462cb978dbd5c0e78", short_id: "cU3Gy" }) `

` Mongo.find(:article, "my_app_db", %{}) |> Enum.to_list `


Now go to http://localhost:4000/write in a browser

You have to enter two user names and passwords

The first is 'foo', password 'baz', and the second is 'foo', password 'bar'

You can now start entering articles. Each article has a name and classification, and you can add any other columns you want. The classifications are listed at the top of the page. The Search feature searches through the articles if you enter three or more characters into the Search box.

The Edit button takes you to an HTML editor, which has a Save button and an auto-save feature.

If you create an article with classification 'sidebar', and give it a 'url' field pointing to another article, the sidebar is shown on the left of the other article, in READ mode, as a retractable nav bar. The URL should contain 'read', e.g.
`http://localhost:4000/read/edit/G1aKp` NOT `http://localhost:4000/write/edit/G1aKp`.

Your articles are initially saved in a memory database, controlled by memory_db.ex. Every few minutes, background_saver.ex checks to see if any of the articles have changed (using a hash in hash_stack.ex), or if there are any new ones. It then synchronises the memory_db with the Mongo DB, which is permanent storage for after the app exits. If you delete an article using the Delete button, it is immediately deleted from the Mongo DB.

How often the auto-saver saves is given by the first number in the following section in the files in the config/ folder:

`config :simple_mongo_app, timings: {27, 11, 17} `

The second number is how often the background_saver transfers those articles in the memory_db which have changed since they were read from the Mongo DB, or are new. The third number is not used currently. For example, if you want to auto-save from the editor every twelve minutes in development mode, and background-save every 25 minutes, you would put the following in config/dev.exs:

`config :simple_mongo_app, timings: {12, 25, 17} `


The user names and passwords are given in the following sections in config/config.exs

```
config :simple_mongo_app, your_config: [
  username: "foo",
  password: "baz",
  realm: "Admin Area"
]

config :simple_mongo_app, my_config: [
  username: "foo",
  password: "bar",
  realm: "Admin Area"
]
```

If you wanted to put this app into production, you would copy these sections into config/prod.exs, and change the user names and passwords to something a bit harder to guess than foo bar and baz

http://localhost:4000 just shows the articles, with a More button for the articles you've added to using the Edit button
