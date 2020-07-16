defmodule Manic.JSONEnvelope do
  @moduledoc """
  Module implementing the Merchant API [JSON Envelope Specification](https://github.com/bitcoin-sv-specs/brfc-misc/tree/master/jsonenvelope).

  Every response payload from the Merchant API is encapsualted in a parent JSON
  object, which is signed by the miner's [Miner ID](https://github.com/bitcoin-sv/minerid-reference).

  Most manic functions return just the parsed payload, but behind the scenes
  the signature is automatically verified against the payload and an error is
  returned if verification fails.
  """

  # JSONEnvelope
  defstruct payload: nil,
            signature: nil,
            public_key: nil,
            encoding: nil,
            mimetype: nil,
            verified: false


  @typedoc """
  JSON Envelope.

  Each parent JSON object contains a JSON encoded payload, signature and public
  key. The public key can be used to verify the signature against the payload.
  """
  @type t :: %__MODULE__{
    payload: String.t,
    signature: String.t,
    public_key: String.t,
    encoding: String.t,
    mimetype: String.t,
    verified: boolean
  }


  @typedoc """
  Merchant API response payload.

  Depending on the request, the payload returned by the Marchant API can contain
  different fields. Manic automatically re-cases all keys in the map to snake-cased
  strings for a more idiomatic Elixir style.

  ## Examples

  The payload for a fee quote request:

      %{
        "api_version" => String.t,
        "current_highest_block_hash" => String.t,
        "current_highest_block_height" => integer,
        "expiry_time" => String.t,
        "fees" => [
          %{
            "fee_type" => String.t,
            "mining_fee" => %{
              "bytes" => integer,
              "satoshis" => integer
            },
            "relay_fee" => %{
              "bytes" => integer,
              "satoshis" => integer
            }
          },
          ...
        ],
        "miner_id" => String.t,
        "miner_reputation" => String.t | nil,
        "timestamp" => String.t
      }

  Example payload from submiting new transactions:

      %{
        "api_version" => String.t,
        "current_highest_block_hash" => String.t,
        "current_highest_block_height" => integer,
        "miner_id" => String.t,
        "return_result" => String.t,
        "result_description" => String.t,
        "timestamp" => String.t,
        "txid" => String.t,
        "tx_scond_mempool_expiry" => integer
      }

  Example payload from querying a transaction's status:

      %{
        "api_version" => String.t,
        "block_hash" => String.t,
        "block_height" => integer,
        "confirmations" => integer,
        "miner_id" => String.t,
        "return_result" => String.t,
        "result_description" => String.t,
        "timestamp" => String.t,
        "tx_scond_mempool_expiry" => integer
      }
  """
  @type payload :: %{
    String.t => String.t | integer | nil
  }


  @doc """
  Builds a [`JSON Envelope`](`t:t/0`) from the given [`map`][`t:map/0`].
  """
  @spec build(map) :: __MODULE__.t
  def build(%{} = body) do
    struct(__MODULE__, [
      payload: body["payload"],
      signature: body["signature"],
      public_key: body["publicKey"],
      encoding: body["encoding"],
      mimetype: body["mimetype"]
    ])
  end


  @doc """
  Verifies the given [`JSON Envelope`](`t:t/0`), by cryptographically verifying
  the envelopes signature against the payload, using the public key in the envelope.

  Adds the boolean result to the `:verified` key, and returns the
  [`JSON Envelope`](`t:t/0`) in an `:ok` tuple.
  """
  @spec verify(__MODULE__.t | map) ::
    {:ok, __MODULE__.t} |
    {:error, Exception.t | String.t}

  def verify(%__MODULE__{public_key: public_key, signature: signature} = env)
    when (is_nil(public_key) or public_key == "")
    or (is_nil(signature) or signature == ""),
    do: {:ok, env}

  def verify(%__MODULE__{} = env) do
    with {:ok, pubkey} <- Base.decode16(env.public_key, case: :mixed) do
      case BSV.Crypto.ECDSA.verify(env.signature, env.payload, pubkey, encoding: :hex) do
        true -> {:ok, Map.put(env, :verified, true)}
        _ -> {:ok, env}
      end
    else
      :error ->
        {:error, "Error decoding public key"}
    end
  end

  def verify(%{} = env), do: build(env) |> verify


  @doc """
  Parses the given [`JSON Envelope's`](`t:t/0`) payload according it its
  specified mime type.

  Returns the result in an `:ok` / `:error` tuple pair.

  The payload's keys are automatically re-cased to snake-cased strings for a
  more idiomatic Elixir style.
  """
  # Currently can safely assume everything is JSON
  @spec parse_payload(__MODULE__.t) :: {:ok, map} | {:error, Exception.t}
  def parse_payload(%__MODULE__{mimetype: _} = env) do
    case Jason.decode(env.payload) do
      {:ok, map} ->
        payload = map
        |> Recase.Enumerable.convert_keys(&Recase.to_snake/1)
        |> Map.put("verified", env.verified)
        {:ok, payload}

      {:error, error} ->
        {:error, error}
    end
  end

end
