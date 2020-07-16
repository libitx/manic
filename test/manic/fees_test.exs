defmodule Manic.FeesTest do
  use ExUnit.Case
  alias Manic.Fees

  setup_all do
    %{
      miner: Manic.miner(:taal),
      tx: "0100000001648ed7d1c1a27ec923445c8d404e227145218c4ce01cf958a898c5a048e8f264020000006a47304402207dc1953455be091c8df18e7f7e1424bc4efdced3e400642f8316e3ef298c3f30022062d833b3f1b94593ec7c088b930e2987475c7d99bf19f5714b12a9facff100df41210273f105be3e7ca116e96c7c40f17267ae05ede7160eb099aa2146a88b6328f4ecffffffff030000000000000000fdc901006a223144535869386876786e36506434546176686d544b7855374255715337636e7868770c57544458565633505a4b474414e5ae89e5bebd2fe585ade5ae892fe99c8de982b119323032302d30342d30365430363a30303a30302b30383a30304c697b22617169223a223538222c22706d3235223a223332222c22706d3130223a223636222c22736f32223a2235222c226e6f32223a223235222c22636f223a22302e373530222c226f33223a223635222c22706f6c223a22504d3130222c22717561223a22e889af227d4cfb78da75d1c16a02311006e077c959964cb29944dfa1d07bf1209e0a6b57b137114aaf2d2d5e446d7b29d59e3c492f22f834d9ea5b3859e826bba4b73fc34cf898b999b0dee89675184ad662c3815094a5293370ca1a298f73415151ba2b9370cdfd9c124f34c55c563fe419c5eb2b9aa5b1fb1e3d7edf66c5cf93fdfa2ed6072a66ae2621d15203775d99fb070013c50da7cab45599c09b04062688999437993f53d91933ade6a7f5d16e37e7e5676842307553aa1b2685c19e02137a93a94c92c74c69dc54bc7f9c173bfbf21882745b379784a60e0a0f071ea4fce1a45f521a399cfae770f6f0605f67f6795f0381688010dd1da7dd0b690c97db22020000000000001976a914666675d887a7ae09835af934096d9fcbbb70eed288ac61290000000000001976a9149e7520bc258934a3d58704ab98ed0200e2c1bb9688ac00000000"
    }
  end


  describe "Manic.Fees.get/2" do
    setup do
      Tesla.Mock.mock fn _env ->
        File.read!("test/mocks/fee_quote.json") |> Jason.decode! |> Tesla.Mock.json
      end
      :ok
    end

    test "should return a fee quote from the miner", ctx do
      {:ok, res} = Fees.get(ctx.miner)
      assert res == %{
        expires: ~U[2020-04-20 16:35:03.168Z],
        mine: %{data: 0.5, standard: 0.5},
        relay: %{data: 0.25, standard: 0.25},
        verified: true
      }
    end

    test "should return the parsed payload", ctx do
      {:ok, res} = Fees.get(ctx.miner, as: :payload)
      assert is_map(res)
      assert res["miner_id"] == "03e92d3e5c3f7bd945dfbf48e7a99393b1bfb3f11f380ae30d286e7ff2aec5a270"
    end

    test "should return the JSON envelope", ctx do
      {:ok, res} = Fees.get(ctx.miner, as: :envelope)
      assert res.__struct__ == Manic.JSONEnvelope
    end
  end


  describe "Manic.Fees.get/2 with invalid signature" do
    setup do
      Tesla.Mock.mock fn _env ->
        File.read!("test/mocks/fee_quote_nosig.json") |> Jason.decode! |> Tesla.Mock.json
      end
      :ok
    end

    test "should return a fee quote with verified false", ctx do
      {:ok, res} = Fees.get(ctx.miner)
      assert res[:verified] == false
    end
  end


  describe "Manic.Fees.get/2 with multi miner" do
    setup do
      Tesla.Mock.mock_global fn _env ->
        File.read!("test/mocks/fee_quote.json") |> Jason.decode! |> Tesla.Mock.json
      end
      %{
        multi: Manic.multi([:taal, :matterpool], yield: :all)
      }
    end

    test "should return all miner responses", ctx do
      res = Fees.get(ctx.multi)
      assert length(res) == 2
      assert {%Manic.Miner{url: :taal}, {:ok, _res}} = List.first(res)
      assert {%Manic.Miner{url: :matterpool}, {:ok, _res}} = List.last(res)
    end
  end


  describe "Manic.Fees.get!/2" do
    setup do
      Tesla.Mock.mock fn _env ->
        File.read!("test/mocks/fee_quote.json") |> Jason.decode! |> Tesla.Mock.json
      end
      :ok
    end

    test "should return a fee quote from the miner", ctx do
      res = Fees.get!(ctx.miner)
      assert res == %{
        expires: ~U[2020-04-20 16:35:03.168Z],
        mine: %{data: 0.5, standard: 0.5},
        relay: %{data: 0.25, standard: 0.25},
        verified: true
      }
    end
  end


  describe "Manic.Fees.calculate/2" do
    setup do
      Tesla.Mock.mock fn _env ->
        File.read!("test/mocks/fee_quote.json") |> Jason.decode! |> Tesla.Mock.json
      end
      :ok
    end

    test "should calculate the fee from the given rates", ctx do
      assert Fees.calculate(%{data: 0.5, standard: 0.5}, ctx.tx) == {:ok, 346}
      assert Fees.calculate(%{data: 0.25, standard: 0.25}, ctx.tx) == {:ok, 173}
      assert Fees.calculate(%{data: 0.25, standard: 0.5}, ctx.tx) == {:ok, 229}
    end

    test "should load rates from the given miner", ctx do
      assert Fees.calculate(ctx.miner, ctx.tx) == {:ok, 346}
    end

    test "should return error when given invalid tx" do
      {:error, error} = Fees.calculate(%{data: 0.5, standard: 0.5}, "aabbeecc")
      assert error == "Not valid transaction"
    end
  end


  describe "Manic.Fees.calculate!/2" do
    test "should calculate the fee from the given rates", ctx do
      assert Fees.calculate!(%{data: 0.5, standard: 0.5}, ctx.tx) == 346
    end

    test "should raise eception when given invalid tx" do
      assert_raise RuntimeError, "Not valid transaction", fn ->
        Fees.calculate!(%{data: 0.5, standard: 0.5}, "aabbeecc")
      end
    end
  end

end
