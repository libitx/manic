defmodule Manic.TX do
  @moduledoc """
  Send transactions directly to miners and query the status of any transaction.

  By giving a transaction directly to a miner (instead of broadcasting it to the
  Bitcoin peer network), you are pushing the transaction directly to the centre
  of the network. As the miner will have already provided the correct fees to
  ensure the transaction is relayed and mined, you can confidently accept the
  transaction on a "zero confirmation" basis.

  This module allows developers to push transactions directly to miners and
  query the status of any transaction. As each payload from the Merchant API
  includes and is signed by the miner's [Miner ID](https://github.com/bitcoin-sv/minerid-reference),
  the response can be treated as a legally binding signed message backed by the
  miner's own proof of work.
  """
  alias Manic.{JSONEnvelope, Miner, Multi}


  @typedoc "Hex-encoded transaction ID."
  @type txid :: String.t


  @doc """
  Sends the given [`transaction`](`t:BSV.Tx.t/0`) directly to a [`miner`](`t:Manic.miner/0`).

  Returns the result in an `:ok` / `:error` tuple pair.

  The transaction can be passed as either a `t:BSV.Tx.t/0` or as a hex
  encoded binary.

  ## Options

  The `:as` option can be used to speficy how to recieve the fees. The accepted
  values are:

  * `:payload` - The decoded JSON [`payload`](`t:Manic.JSONEnvelope.payload/0`) **(Default)**
  * `:envelope` - The raw [`JSON envolope`](`t:Manic.JSONEnvelope.t/0`)

  ## Examples

  To push a transaction to the minder.

      iex> Manic.TX.push(miner, tx)
      {:ok, %{
        "api_version" => "0.1.0",
        "current_highest_block_hash" => "00000000000000000397a5a37c1f9b409b4b58e76fd6bcac06db1a3004cccb38",
        "current_highest_block_height" => 631603,
        "miner_id" => "03e92d3e5c3f7bd945dfbf48e7a99393b1bfb3f11f380ae30d286e7ff2aec5a270",
        "result_description" => "",
        "return_result" => "success",
        "timestamp" => "2020-04-21T14:04:39.563Z",
        "tx_second_mempool_expiry" => 0,
        "txid" => "9c8c5cf37f4ad1a82891ff647b13ec968f3ccb44af2d9deaa205b03ab70a81fa",
        "verified" => true
      }}

  Using the `:as` option to return the [`JSON envolope`](`t:Manic.JSONEnvelope.t/0`).

      iex> Manic.TX.push(miner, tx, as: :envelope)
      {:ok, %Manic.JSONEnvelope{
        encoding: "UTF-8",
        mimetype: "application/json",
        payload: "{\\"apiVersion\\":\\"0.1.0\\",\\"timestamp\\":\\"2020-04-21T14:04:39.563Z\\",\\"txid\\":\\"\\"9c8c5cf37f4ad1a82891ff647b13ec968f3ccb44af2d9deaa205b03ab70a81fa\\"\\",\\"returnResult\\":\\"success\\",\\"resultDescription\\":\\"\\",\\"minerId\\":\\"03e92d3e5c3f7bd945dfbf48e7a99393b1bfb3f11f380ae30d286e7ff2aec5a270\\",\\"currentHighestBlockHash\\":\\"00000000000000000397a5a37c1f9b409b4b58e76fd6bcac06db1a3004cccb38\\",\\"currentHighestBlockHeight\\":631603,\\"txSecondMempoolExpiry\\":0}",
        public_key: "03e92d3e5c3f7bd945dfbf48e7a99393b1bfb3f11f380ae30d286e7ff2aec5a270",
        signature: "3045022100a490e469426f34fcf62d0f095c10039cf5a1d535c042172786c364d41de65b3a0220654273ca42b5e955179d617ea8252e64ddf74657aa0caebda7372b40a0f07a53",
        verified: true
      }}

  """
  @spec push(Manic.miner | Manic.multi_miner, BSV.Tx.t | String.t, keyword) ::
    {:ok, JSONEnvelope.payload | JSONEnvelope.t} |
    {:error, Exception.t} |
    Multi.result

  def push(miner, tx, options \\ [])

  def push(%Miner{} = miner, %BSV.Tx{} = tx, options),
    do: push(miner, BSV.Tx.to_binary(tx, encoding: :hex), options)

  def push(%Miner{} = miner, tx, options) when is_binary(tx) do
    format = Keyword.get(options, :as, :payload)

    with {:ok, _tx} <- validate_tx(tx),
         {:ok, %{body: body, status: status}} when status in 200..202 <- Tesla.post(miner.client, "/mapi/tx", %{"rawtx" => tx}),
         {:ok, body} <- JSONEnvelope.verify(body),
         {:ok, payload} <- JSONEnvelope.parse_payload(body)
    do
      res = case format do
        :envelope -> body
        _ -> payload
      end
      {:ok, res}
    else
      {:ok, res} ->
        {:error, "HTTP Error: #{res.status}"}
      {:error, err} ->
        {:error, err}
    end
  end

  def push(%Multi{} = multi, tx, options) do
    multi
    |> Multi.async(__MODULE__, :push, [tx, options])
    |> Multi.yield
  end


  @doc """
  As `push/3` but returns the result or raises an exception if it fails.
  """
  @spec push!(Manic.miner | Manic.multi_miner, BSV.Tx.t | String.t, keyword) ::
    JSONEnvelope.payload | JSONEnvelope.t

  def push!(miner, tx, options \\ []) do
    case push(miner, tx, options) do
      {:ok, res} -> res
      {:error, error} -> raise error
    end
  end


  @doc """
  Query the status of a transaction by its [`txid`](`t:txid/0`), from the given
  [`miner`](`t:Manic.miner/0`).

  Returns the result in an `:ok` / `:error` tuple pair.

  ## Options

  The `:as` option can be used to speficy how to recieve the fees. The accepted
  values are:

  * `:payload` - The decoded JSON [`payload`](`t:Manic.JSONEnvelope.payload/0`) **(Default)**
  * `:envelope` - The raw [`JSON envolope`](`t:Manic.JSONEnvelope.t/0`)

  ## Examples

  To get the status of a transaction/

      iex> Manic.TX.boradcast(miner, "e4763d71925c2ac11a4de0b971164b099dbdb67221f03756fc79708d53b8800e")
      {:ok, %{
        "api_version" => "0.1.0",
        "block_hash" => "000000000000000000983dee680071d63939f4690a8a797c022eddadc88f925e",
        "block_height" => 630712,
        "confirmations" => 765,
        "miner_id" => "03e92d3e5c3f7bd945dfbf48e7a99393b1bfb3f11f380ae30d286e7ff2aec5a270",
        "result_description" => "",
        "return_result" => "success",
        "timestamp" => "2020-04-20T21:45:38.808Z",
        "tx_second_mempool_expiry" => 0,
        "verified" => true
      }}

  Using the `:as` option to return the [`JSON envolope`](`t:Manic.JSONEnvelope.t/0`).

      iex> Manic.TX.boradcast(miner, tx, as: :envelope)
      {:ok, %Manic.JSONEnvelope{
        encoding: "UTF-8",
        mimetype: "application/json",
        payload: "{\\"apiVersion\\":\\"0.1.0\\",\\"timestamp\\":\\"2020-04-20T21:45:38.808Z\\",\\"returnResult\\":\\"success\\",\\"resultDescription\\":\\"\\",\\"blockHash\\":\\"000000000000000000983dee680071d63939f4690a8a797c022eddadc88f925e\\",\\"blockHeight\\":630712,\\"confirmations\\":765,\\"minerId\\":\\"03e92d3e5c3f7bd945dfbf48e7a99393b1bfb3f11f380ae30d286e7ff2aec5a270\\",\\"txSecondMempoolExpiry\\":0}",
        public_key: "03e92d3e5c3f7bd945dfbf48e7a99393b1bfb3f11f380ae30d286e7ff2aec5a270",
        signature: "304502210092b822497cfe065136522b33b0fbec790c77f62818bd252583a615efd35697af022059c4ca7e97c90960860ed9d7b0ff4a1601cfe207b638c672c60a44027aed1f2d",
        verified: true
      }}

  """
  @spec status(Manic.miner | Manic.multi_miner, TX.txid, keyword) ::
    {:ok, JSONEnvelope.payload | JSONEnvelope.t} |
    {:error, Exception.t} |
    Multi.result

  def status(miner, txid, options \\ [])

  def status(%Miner{} = miner, txid, options) when is_binary(txid) do
    format = Keyword.get(options, :as, :payload)

    with {:ok, txid} <- validate_txid(txid),
         {:ok, %{body: body, status: status}} when status in 200..202 <- Tesla.get(miner.client, "/mapi/tx/" <> txid),
         {:ok, body} <- JSONEnvelope.verify(body),
         {:ok, payload} <- JSONEnvelope.parse_payload(body)
    do
      res = case format do
        :envelope -> body
        _ -> payload
      end
      {:ok, res}
    else
      {:ok, res} ->
        {:error, "HTTP Error: #{res.status}"}
      {:error, err} ->
        {:error, err}
    end
  end

  def status(%Multi{} = multi, txid, options) do
    multi
    |> Multi.async(__MODULE__, :status, [txid, options])
    |> Multi.yield
  end


  @doc """
  As `status/3` but returns the result or raises an exception if it fails.
  """
  @spec status!(Manic.miner | Manic.multi_miner, String.t, keyword) ::
    JSONEnvelope.payload | JSONEnvelope.t

  def status!(miner, txid, options \\ []) do
    case status(miner, txid, options) do
      {:ok, res} -> res
      {:error, error} -> raise error
    end
  end


  # Validates the given transaction binary by attempting to parse it.
  defp validate_tx(tx) when is_binary(tx) do
    try do
      {:ok, BSV.Tx.from_binary!(tx, encoding: :hex)}
    rescue
      _err -> {:error, "Not valid transaction"}
    end
  end


  # Validates the given txid binary by regex matching it.
  defp validate_txid(txid) do
    case String.match?(txid, ~r/^[a-f0-9]{64}$/i) do
      true -> {:ok, txid}
      false -> {:error, "Not valid TXID"}
    end
  end

end
