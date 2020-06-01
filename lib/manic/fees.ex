defmodule Manic.Fees do
  @moduledoc """
  Query dynamic fee rates from Bitcoin miners, and calculate accurate
  transaction fees.

  Miners are moving to a model where they will fix their fees in Fiat terms. In
  addition, miners will compete with each other and some may specialise in
  different types on transactions. All of this will lead to a fluid fee market
  where the rates offered by miners will differ and shift over time.

  This module allows developers to query miners directly for up to date fee rates,
  plus calculate accurate fees for any given transaction.
  """
  alias Manic.{JSONEnvelope, Multi}


  @typedoc """
  The type of transaction data any given fee applies to.
  
  Currently fees are broken down by `standard` and `data` types. `data` fees are
  applied to any data carrier output (`OP_RETURN`) whereas all other transaction
  data is priced at the standard rate. In future other fee types may be introduced.
  """
  @type fee_type :: :standard | :data | atom


  @typedoc """
  Fee rates broken down by [`fee types`](`t:fee_type/0`).
  """
  @type fee_rates :: %{
    optional(fee_type) => float
  }


  @typedoc """
  A simplified miner fee quote.

  The quote contains an expiry date, allowing developers to know when the quoted
  fees remain valid until. [`Fee rates`](`t:fee_rates/0`) are further broken
  down by:

  * `:mine` - Minimum threshold where a miner would be willing to mine the transaction
  * `:relay` - Minimum threshold where a miner would be willing to relay and hold a transaction in their mempool
  """
  @type fee_quote :: %{
    expires: DateTime.t,
    mine: fee_rates,
    relay: fee_rates
  }


  @doc """
  Get a [`fee quote`](`t:fee_quote/0`) from the given [`miner`](`t:Manic.miner/0`).

  Returns the result in an `:ok` / `:error` tuple pair.

  ## Options

  The `:as` option can be used to speficy how to recieve the fees. The accepted
  values are:

  * `:fees` - The structured [`fee quote`](`t:fee_quote/0`) data **(Default)**
  * `:payload` - The decoded JSON [`payload`](`t:Manic.JSONEnvelope.payload/0`)
  * `:envelope` - The raw [`JSON envolope`](`t:Manic.JSONEnvelope.t/0`)

  ## Examples

  To get a fee quote from the given miner.

      iex> Manic.Fees.get(miner)
      {:ok, %{
        mine: %{data: 0.5, standard: 0.5},
        relay: %{data: 0.25, standard: 0.25}
      }}

  Using the `:as` option to return the [`JSON envolope`](`t:Manic.JSONEnvelope.t/0`).

      iex> Manic.Fees.get(miner, as: :envelope)
      {:ok, %Manic.JSONEnvelope{
        encoding: "UTF-8",
        mimetype: "application/json",
        payload: "{\\"apiVersion\\":\\"0.1.0\\",\\"timestamp\\":\\"2020-04-20T14:10:15.079Z\\",\\"expiryTime\\":\\"2020-04-20T14:20:15.079Z\\",\\"minerId\\":\\"03e92d3e5c3f7bd945dfbf48e7a99393b1bfb3f11f380ae30d286e7ff2aec5a270\\",\\"currentHighestBlockHash\\":\\"00000000000000000020900d959b83325068f28ff635cb541888ef16ec8ebaf7\\",\\"currentHighestBlockHeight\\":631451,\\"minerReputation\\":null,\\"fees\\":[{\\"feeType\\":\\"standard\\",\\"miningFee\\":{\\"satoshis\\":5,\\"bytes\\":10},\\"relayFee\\":{\\"satoshis\\":25,\\"bytes\\":100}},{\\"feeType\\":\\"data\\",\\"miningFee\\":{\\"satoshis\\":5,\\"bytes\\":10},\\"relayFee\\":{\\"satoshis\\":25,\\"bytes\\":100}}]}",
        public_key: "03e92d3e5c3f7bd945dfbf48e7a99393b1bfb3f11f380ae30d286e7ff2aec5a270",
        signature: "304402206fc2744bc3626e5becbc3a708760917c6f78f83a61fd557b238c613862929412022047d22f89bd6fe98ca50e819452db81318641f74544252b1f04536cc689cf5f55"
      }}
  """
  @spec get(Manic.miner | Multi.t, keyword) ::
    {:ok, fee_quote | JSONEnvelope.payload | JSONEnvelope.t} |
    {:error, Exception.t} |
    Multi.result

  def get(miner, options \\ [])

  def get(%Tesla.Client{} = miner, options) do
    format = Keyword.get(options, :as, :fees)

    with {:ok, res} <- Tesla.get(miner, "/mapi/feeQuote"),
         {:ok, body} <- JSONEnvelope.verify(res.body),
         {:ok, payload} <- JSONEnvelope.parse_payload(body),
         {:ok, fees} <- build_fee_quote(payload)
    do
      res = case format do
        :envelope -> body
        :payload -> payload
        _ -> fees
      end
      {:ok, res}
    else
      {:error, err} ->
        {:error, err}
    end
  end

  def get(%Multi{} = multi, options) do
    multi
    |> Multi.async(__MODULE__, :get, [options])
    |> Multi.yield
  end


  @doc """
  As `get/2` but returns the result or raises an exception if it fails.
  """
  @spec get!(Manic.miner, keyword) ::
    fee_quote | JSONEnvelope.payload | JSONEnvelope.t

  def get!(%Tesla.Client{} = miner, options \\ []) do
    case get(miner, options) do
      {:ok, fees} -> fees
      {:error, error} -> raise error
    end
  end


  # Builds the simplified `t:fee_quote/0` map from the given payload.
  defp build_fee_quote(%{"expiry_time" => expires, "fees" => fees})
    when is_list(fees)
  do
    {:ok, expires, _} = DateTime.from_iso8601(expires)
    fees = Enum.reduce(fees, %{expires: expires, mine: %{}, relay: %{}}, fn f, fees ->
      type = String.to_atom(f["fee_type"])
      %{"mining_fee" => m, "relay_fee" => r} = f

      fees
      |> Map.update!(:mine, & Map.put(&1, type, m["satoshis"] / m["bytes"]))
      |> Map.update!(:relay, & Map.put(&1, type, r["satoshis"] / r["bytes"]))
    end)
    {:ok, fees}
  end


  @doc """
  Calculates the fee of the given [`transaction`](`t:BSV.Transaction.t/0`) using
  the specified [`rates`](`t:fee_rates/0`).

  Returns the fee in satoshis as an `t:integer/0`.

  If a [`miner`](`t:Manic.miner/0`) is passed as the first argument, the
  function firstly gets the [`rates`](`t:fee_rates/0`) for that miner, before
  calculating the fee for the given transaction. The transaction can be passed
  as either a `t:BSV.Transaction.t/0` or as a hex encoded binary.

  ## Example

      iex> Manic.Fees.calculate(%{data: 0.5, standard: 0.5}, tx)
      346
  """
  @spec calculate(fee_rates | Manic.miner, BSV.Transaction.t | String.t) ::
    {:ok, integer} |
    {:error, Exception.t}

  def calculate(rates, tx)

  def calculate(%Tesla.Client{} = miner, tx) do
    case get(miner) do
      {:ok, %{mine: rates}} ->
        calculate(rates, tx)

      {:error, error} ->
        {:error, error}
    end
  end

  def calculate(%{} = rates, tx) when is_binary(tx) do
    case validate_tx(tx) do
      {:ok, tx} ->
        calculate(rates, tx)

      {:error, error} ->
        {:error, error}
    end
  end

  def calculate(%{} = rates, %BSV.Transaction{} = tx) do
    try do
      parts = [
        {:standard, 4}, # version
        {:standard, 4}, # locktime
        {:standard, length(tx.inputs) |> BSV.Util.VarBin.serialize_int |> byte_size},
        {:standard, length(tx.outputs) |> BSV.Util.VarBin.serialize_int |> byte_size}
      ]
      |> Kernel.++(Enum.map(tx.inputs, &calc_script_size/1))
      |> Kernel.++(Enum.map(tx.outputs, &calc_script_size/1))

      fee = parts
      |> Enum.map(& rates[elem(&1, 0)] * elem(&1, 1))
      |> Enum.sum
      |> Kernel.trunc

      {:ok, fee}
    rescue error ->
      {:error, error}
    end
  end


  @doc """
  As `calculate/2` but returns the result or raises an exception if it fails.
  """
  @spec calculate!(fee_rates | Manic.miner, BSV.Transaction.t | String.t) ::
    integer

  def calculate!(rates, tx) do
    case calculate(rates, tx) do
      {:ok, fee} -> fee
      {:error, error} -> raise error
    end
  end


  # Validates the given transaction binary by attempting to parse it.
  defp validate_tx(tx) when is_binary(tx) do
    try do
      {%BSV.Transaction{} = tx, ""} = BSV.Transaction.parse(tx, encoding: :hex)
      {:ok, tx}
    rescue
      _err -> {:error, "Not valid transaction"}
    end
  end


  # Calculates the given input or output size and returns a tuple pair where the
  # first element is the `t:fee_type/0`.
  defp calc_script_size(%BSV.Transaction.Input{} = input),
    do: {:standard, BSV.Transaction.Input.get_size(input)}

  defp calc_script_size(%BSV.Transaction.Output{script: nil} = output),
    do: {:standard, BSV.Transaction.Output.get_size(output)}

  defp calc_script_size(%BSV.Transaction.Output{script: script} = output) do
    case script.chunks do
      [:OP_FALSE, :OP_RETURN | _chunks] ->
        {:data, BSV.Transaction.Output.get_size(output)}
      _ ->
        {:standard, BSV.Transaction.Output.get_size(output)}
    end
  end  
end
