use Mix.Config

case Mix.env do
  :test ->
    config :logger, level: :error
    config :tesla, adapter: Tesla.Mock
  _ ->
    config :tesla, adapter: {Tesla.Adapter.Mint, [
      timeout: :infinity,
      protocols: [:http1]
    ]}
end
