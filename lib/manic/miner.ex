defmodule Manic.Miner do
  @moduledoc """
  Module for encapsulating a miner Merchant API client.
  """
  defstruct [:url, :options, :client]


  @typedoc "Bitcoin miner API client"
  @type t :: %__MODULE__{
    url: String.t | atom,
    options: keyword,
    client: Tesla.Client.t
  }

  # Hard coded list of known miners
  @miners %{
    matterpool: "https://merchantapi.matterpool.io",
    mempool: "https://www.ddpurse.com/openapi",
    taal: "https://merchantapi.taal.com"
  }


  @doc """
  Returns a map of Manic's known miners.
  """
  @spec known_miners() :: map
  def known_miners, do: @miners


  @doc """
  Returns a [`miner`](`t:t/0`) client for the given URL.
  """
  @spec new({String.t | atom, keyword}) :: __MODULE__.t
  def new({url, options}) do
    new(url, options)
  end

  @spec new(String.t | atom, keyword) :: __MODULE__.t
  def new(url, options \\ []) do
    struct(__MODULE__, [
      url: url,
      options: options,
      client: client(url, options)
    ])
  end


  @doc """
  Returns a [`HTTP client`](`t:Tesla.Client.t/0`) for the given URL.
  """
  @spec client(String.t | atom, keyword) :: Tesla.Client.t
  def client(url, options) when is_atom(url) do
    case @miners[url] do
      nil -> raise  "Unknown miner `#{inspect url}`. Please specify URL endpoint."
      url -> client(url, options)
    end
  end

  def client(url, options) do
    headers = Keyword.get(options, :headers, [])
    middleware = [
      {Tesla.Middleware.BaseUrl, url},
      {Tesla.Middleware.Headers, [{"content-type", "application/json"} | headers]},
      Tesla.Middleware.JSON
    ]
    Tesla.client(middleware)
  end

end
