defmodule ManicTest do
  use ExUnit.Case
  alias Manic.Miner

  describe "Manic.known_miners/0" do
    test "should return a map of known miners" do
      miners = Manic.known_miners
      assert is_map(miners)
      assert Map.keys(miners) |> Enum.member?(:taal)
      assert Map.keys(miners) |> Enum.member?(:mempool)
    end
  end


  describe "Manic.miner/2" do
    test "should return a miner client from a full URL" do
      assert %Miner{client: client} = Manic.miner "https://merchantapi.taal.com"
      {_, _, [url]} = Enum.find(client.pre, & elem(&1, 0) == Tesla.Middleware.BaseUrl)
      assert client.__struct__ == Tesla.Client
      assert url == "https://merchantapi.taal.com"
    end

    test "should return a miner client from a symbol" do
      assert %Miner{client: client} = Manic.miner :taal
      {_, _, [url]} = Enum.find(client.pre, & elem(&1, 0) == Tesla.Middleware.BaseUrl)
      assert client.__struct__ == Tesla.Client
      assert url == "https://merchantapi.taal.com"
    end

    test "should return a miner client with given headers" do
      assert %Miner{client: client} = Manic.miner :mempool, headers: [{"token", "abcdefg"}]
      {_, _, [url]} = Enum.find(client.pre, & elem(&1, 0) == Tesla.Middleware.BaseUrl)
      {_, _, [headers]} = Enum.find(client.pre, & elem(&1, 0) == Tesla.Middleware.Headers)
      assert client.__struct__ == Tesla.Client
      assert url == "https://www.ddpurse.com/openapi"
      assert Enum.member?(headers, {"token", "abcdefg"})
    end
  end

end
