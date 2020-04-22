# Manic

Manic is an Elixir client for interfacing with Bitcoin miner APIs.

Manic is a port of [unwriter's](https://twitter.com/_unwriter) [Minercraft](https://minercraft.network) library for JavaScript. Like Minercraft, Manic supports the [beta version of the Merchant API](https://bitcoinsv.io/2020/04/03/miner-id-and-merchant-api-beta-release/), and its name is a nod to another classic computer game.

## Features

Manic supports the following features:

* Get dynamic fee rates from miners
* Calculate the fee for any transaction
* Push transactions directly to miners
* Get the status of any transaction from miners

| Implemented spec | BRFC |
| ---------------- | ---- |
| [Merchant API Specification](https://github.com/bitcoin-sv-specs/brfc-merchantapi) | `ce852c4c2cd1` |
| [Fee Specification](https://github.com/bitcoin-sv-specs/brfc-misc/tree/master/feespec) | `fb567267440a` |
| [JSON Envelope Specification](https://github.com/bitcoin-sv-specs/brfc-misc/tree/master/jsonenvelope) | `298e080a4598` |

## Installation

The package can be installed by adding `manic` to your list of dependencies
in `mix.exs`.

```elixir
def deps do
  [
    {:manic, "~> 0.0.1"}
  ]
end
```

## Usage

For detailed examples, refer to the [full documentation](https://hexdocs.pm/manic).

### 1. Initalize a miner client

Initialize a miner client with the full URL of the Merchant API endpoint.

```elixir
iex> miner = Manic.miner "https://merchantapi.taal.com"
%Tasla.Client{}
```

A client can aslo be initialized using any of the keys from a list of known miners. Additional headers can also be specified if necessary.

```elixir
iex> miner = Manic.miner :mempool, headers: [{"token", token}]
%Tasla.Client{}
```

### 2. Get and calculate fees

The miner client can then be used to query the miner's up-to-date fee rates.

```elixir
iex> Manic.Fees.get(miner)
{:ok, %{
  expires: ~U[2020-04-20 16:35:03.168Z],
  mine: %{data: 0.5, standard: 0.5},
  relay: %{data: 0.25, standard: 0.25}
}}
```

The fee for a transaction can be calculated using the given rates.

```elixir
iex> Manic.Fees.calculate(rates.mine, tx)
{:ok, 346}
```

### 3. Push and query transactions

Manic can be used to push transactions directly to the miner.

```elixir
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
  "txid" => "9c8c5cf37f4ad1a82891ff647b13ec968f3ccb44af2d9deaa205b03ab70a81fa"
}}
```

Any transaction's status can be queried by its `txid`.

```elixir
iex> Manic.TX.status(miner, "e4763d71925c2ac11a4de0b971164b099dbdb67221f03756fc79708d53b8800e")
{:ok, %{
  "api_version" => "0.1.0",
  "block_hash" => "000000000000000000983dee680071d63939f4690a8a797c022eddadc88f925e",
  "block_height" => 630712,
  "confirmations" => 765,
  "miner_id" => "03e92d3e5c3f7bd945dfbf48e7a99393b1bfb3f11f380ae30d286e7ff2aec5a270",
  "result_description" => "",
  "return_result" => "success",
  "timestamp" => "2020-04-20T21:45:38.808Z",
  "tx_second_mempool_expiry" => 0
}}
```

For more examples, refer to the [full documentation](https://hexdocs.pm/manic).

## License

[MIT License](https://github.com/libitx/manic/blob/master/LICENSE.md).

© Copyright 2020 libitx.