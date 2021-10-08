defmodule Manic.TXTest do
  use ExUnit.Case
  alias Manic.TX

  setup_all do
    %{
      miner: Manic.miner(:taal),
      tx_ok: "0100000001408d1dbeb63b3c917f8b1a9ac514b917e4b151aa5b4db615cda5dca4455e3095000000006a473044022050b1774cc81a83a7a1ac94a3356fdae8ed6d5c6dfa101fb1caab98f649c677b10220033b4f1ec51810753577ebbecb220c84ff104cae4a690cf44964125eb2c9fc0c4121032cebae50214f26b45d356a3d9d70324cb593affd1c13065f4d2f0110ad5e2661ffffffff0200000000000000000f006a0c48656c6c6f20776f726c642184190000000000001976a91451d0b8a2ffb9fa78ecd898f54d657d3096174e7088ac00000000",
      tx_bad: "01000000000100000000000000000f006a0c48656c6c6f20776f726c642100000000"

    }
  end


  describe "Manic.TX.push/3" do
    setup ctx do
      Tesla.Mock.mock fn env ->
        cond do
          String.match?(env.body, Regex.compile!("\"#{ ctx.tx_ok }\"")) ->
            File.read!("test/mocks/tx_push-success.json") |> Jason.decode! |> Tesla.Mock.json
          String.match?(env.body, Regex.compile!("\"#{ ctx.tx_bad }\"")) ->
            File.read!("test/mocks/tx_push-failure.json") |> Jason.decode! |> Tesla.Mock.json
        end
      end
      :ok
    end

    test "should return the parsed payload", ctx do
      {:ok, res} = TX.push(ctx.miner, ctx.tx_ok)
      assert is_map(res)
      assert res["miner_id"] == "03e92d3e5c3f7bd945dfbf48e7a99393b1bfb3f11f380ae30d286e7ff2aec5a270"
      assert res["return_result"] == "success"
      #assert res["txid"] == "9c8c5cf37f4ad1a82891ff647b13ec968f3ccb44af2d9deaa205b03ab70a81fa"
      assert res["verified"] == true
    end

    test "should return the parsed payload for failed tx", ctx do
      {:ok, res} = TX.push(ctx.miner, ctx.tx_bad)
      assert is_map(res)
      assert res["return_result"] == "failure"
      assert res["result_description"] == "Not enough fees"
      assert res["txid"] == ""
    end

    test "should return the JSON envelope", ctx do
      {:ok, res} = TX.push(ctx.miner, ctx.tx_ok, as: :envelope)
      assert res.__struct__ == Manic.JSONEnvelope
    end

    test "should return error when given invalid tx", ctx do
      {:error, error} = TX.push(ctx.miner, "aabbeecc")
      assert error == "Not valid transaction"
    end
  end


  describe "Manic.TX.push/3 with multi miner" do
    setup do
      Tesla.Mock.mock_global fn _env ->
        File.read!("test/mocks/tx_push-success.json") |> Jason.decode! |> Tesla.Mock.json
      end
      %{
        multi: Manic.multi([:taal, :matterpool], yield: :any)
      }
    end

    test "should return first miner response", ctx do
      res = TX.push(ctx.multi, ctx.tx_ok)
      assert {%Manic.Miner{url: :taal}, {:ok, _res}} = res
    end
  end


  describe "Manic.TX.push!/3" do
    setup do
      Tesla.Mock.mock fn _env ->
        File.read!("test/mocks/tx_push-success.json") |> Jason.decode! |> Tesla.Mock.json
      end
      :ok
    end

    test "should return the parsed payload", ctx do
      res = TX.push!(ctx.miner, ctx.tx_ok)
      assert is_map(res)
      assert res["miner_id"] == "03e92d3e5c3f7bd945dfbf48e7a99393b1bfb3f11f380ae30d286e7ff2aec5a270"
      assert res["return_result"] == "success"
    end

    test "should raise eception when given invalid tx", ctx do
      assert_raise RuntimeError, "Not valid transaction", fn ->
        TX.push!(ctx.miner, "aabbeecc")
      end
    end
  end


  describe "Manic.TX.status/3" do
    setup do
      Tesla.Mock.mock fn env ->
        cond do
          String.ends_with?(env.url, "e4763d71925c2ac11a4de0b971164b099dbdb67221f03756fc79708d53b8800e") ->
            File.read!("test/mocks/tx_status-confirmed.json") |> Jason.decode! |> Tesla.Mock.json
          String.ends_with?(env.url, "a46f29e56e674146961c6ac5fd84729ea9320569732f4f807d7bda180a74de5d") ->
            File.read!("test/mocks/tx_status-mempool.json") |> Jason.decode! |> Tesla.Mock.json
          String.ends_with?(env.url, "a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1") ->
            File.read!("test/mocks/tx_status-not_found.json") |> Jason.decode! |> Tesla.Mock.json
        end
      end
      :ok
    end

    test "should return the parsed payload", ctx do
      {:ok, res} = TX.status(ctx.miner, "e4763d71925c2ac11a4de0b971164b099dbdb67221f03756fc79708d53b8800e")
      assert is_map(res)
      assert res["miner_id"] == "03e92d3e5c3f7bd945dfbf48e7a99393b1bfb3f11f380ae30d286e7ff2aec5a270"
      assert res["return_result"] == "success"
      assert res["block_hash"] == "000000000000000000983dee680071d63939f4690a8a797c022eddadc88f925e"
      assert res["block_height"] == 630712
      assert res["confirmations"] > 0
      assert res["verified"] == true
    end

    test "should return the parsed payload for mempool tx", ctx do
      {:ok, res} = TX.status(ctx.miner, "a46f29e56e674146961c6ac5fd84729ea9320569732f4f807d7bda180a74de5d")
      assert is_map(res)
      assert res["return_result"] == "success"
      assert res["block_hash"] == ""
      assert res["block_height"] == 0
      assert res["confirmations"] == 0
    end

    test "should return the parsed payload for not found tx", ctx do
      {:ok, res} = TX.status(ctx.miner, "a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1")
      assert is_map(res)
      assert res["return_result"] == "failure"
      assert res["result_description"] == "ERROR: No such mempool or blockchain transaction. Use gettransaction for wallet transactions."
    end

    test "should return the JSON envelope", ctx do
      {:ok, res} = TX.status(ctx.miner, "e4763d71925c2ac11a4de0b971164b099dbdb67221f03756fc79708d53b8800e", as: :envelope)
      assert res.__struct__ == Manic.JSONEnvelope
    end

    test "should return error when given invalid txid", ctx do
      {:error, error} = TX.status(ctx.miner, "aabbeecc")
      assert error == "Not valid TXID"
    end
  end


  describe "Manic.TX.status/3 with invalid signature" do
    setup do
      Tesla.Mock.mock fn _env ->
        File.read!("test/mocks/tx_status-confirmed-nosig.json") |> Jason.decode! |> Tesla.Mock.json
      end
      :ok
    end

    test "should return the parsed payload", ctx do
      {:ok, res} = TX.status(ctx.miner, "e4763d71925c2ac11a4de0b971164b099dbdb67221f03756fc79708d53b8800e")
      assert res["verified"] == false
    end
  end


  describe "Manic.TX.status!/3" do
    setup do
      Tesla.Mock.mock fn _env ->
        File.read!("test/mocks/tx_status-confirmed.json") |> Jason.decode! |> Tesla.Mock.json
      end
      :ok
    end

    test "should return the parsed payload", ctx do
      res = TX.status!(ctx.miner, "e4763d71925c2ac11a4de0b971164b099dbdb67221f03756fc79708d53b8800e")
      assert is_map(res)
      assert res["miner_id"] == "03e92d3e5c3f7bd945dfbf48e7a99393b1bfb3f11f380ae30d286e7ff2aec5a270"
    end

    test "should raise eception when given invalid tx", ctx do
      assert_raise RuntimeError, "Not valid TXID", fn ->
        TX.status!(ctx.miner, "aabbeecc")
      end
    end
  end

end
