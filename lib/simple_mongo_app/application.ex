defmodule SimpleMongoApp.Application do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      supervisor(SimpleMongoAppWeb.Endpoint,  [] ),
      worker( SimpleMongoApp.HashStack,       [] ),
      worker( SimpleMongoApp.MongoDb,         [] ),
      worker( SimpleMongoApp.MemoryDb,        [] ),
      worker( SimpleMongoApp.BackgroundSaver, [] )
    ]

    opts = [strategy: :one_for_one, name: SimpleMongoApp.Supervisor]
    result = Supervisor.start_link(children, opts)
    SimpleMongoApp.MemoryDb.fill()
    result
  end

  def config_change(changed, _new, removed) do
    SimpleMongoAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
