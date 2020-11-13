defmodule SimpleMongoApp.Mongodb do

  def start_link do
    Mongo.start_link(
      name: :article,
      database: "my_app_db",
      hostname: "localhost",
      username: "root",
      password: "rootpassword"
    )
  end

end
