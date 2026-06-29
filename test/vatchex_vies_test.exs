# SPDX-FileCopyrightText: 2024 Isaak Tsalicoglou <isaak@waseigo.com>
# SPDX-License-Identifier: Apache-2.0

defmodule VatchexViesTest do
  use ExUnit.Case

  alias VatchexVies

  @valid_response %{
    countryCode: "EL",
    vatNumber: "998144460",
    valid: true,
    name: "ΟΝΟΜΑΣΙΑ ΕΤΑΙΡΕΙΑΣ",
    address: "ΟΔΟΣ 10\nΑΘΗΝΑ"
  }

  @invalid_response %{
    countryCode: "EL",
    vatNumber: "123456789",
    valid: false
  }

  @status_response %{
    countries: [
      %{countryCode: "EL", availability: "Available"},
      %{countryCode: "FR", availability: "Unavailable"}
    ]
  }

  describe "lookup/3" do
    test "returns company data for valid VAT" do
      Req.Test.stub(VatchexVies, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(@valid_response))
      end)

      assert {:ok, result} = VatchexVies.lookup("EL", "998144460", plug: {Req.Test, VatchexVies})
      assert result[:afm] == "998144460"
      assert result[:onomasia] == "ΟΝΟΜΑΣΙΑ ΕΤΑΙΡΕΙΑΣ"
      assert result[:address] == "ΟΔΟΣ 10 ΑΘΗΝΑ"
      assert result[:country_code] == "EL"
      assert result[:source] == :vies
    end

    test "returns error for invalid VAT" do
      Req.Test.stub(VatchexVies, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(@invalid_response))
      end)

      assert {:error, :invalid_vat} =
               VatchexVies.lookup("EL", "123456789", plug: {Req.Test, VatchexVies})
    end

    test "returns error on transport failure" do
      Req.Test.stub(VatchexVies, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, {:vies_request_failed, _}} =
               VatchexVies.lookup("EL", "998144460", plug: {Req.Test, VatchexVies})
    end

    test "returns error on non-200 response" do
      Req.Test.stub(VatchexVies, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "text/plain")
        |> Plug.Conn.resp(500, "Server Error")
      end)

      assert {:error, {:vies_http_error, 500}} =
               VatchexVies.lookup("EL", "998144460", plug: {Req.Test, VatchexVies})
    end
  end

  describe "available_countries/0" do
    test "returns country map on success" do
      Req.Test.stub(VatchexVies, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(@status_response))
      end)

      assert {:ok, countries} = VatchexVies.available_countries(plug: {Req.Test, VatchexVies})
      assert countries["EL"] == true
      assert countries["FR"] == false
    end

    test "returns error on failure" do
      Req.Test.stub(VatchexVies, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, :vies_status_unavailable} =
               VatchexVies.available_countries(plug: {Req.Test, VatchexVies})
    end
  end

  describe "available?/1" do
    test "returns true for available country" do
      Req.Test.stub(VatchexVies, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(@status_response))
      end)

      assert {:ok, true} = VatchexVies.available?("EL", plug: {Req.Test, VatchexVies})
    end

    test "returns false for unavailable country" do
      Req.Test.stub(VatchexVies, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(@status_response))
      end)

      assert {:ok, false} = VatchexVies.available?("FR", plug: {Req.Test, VatchexVies})
    end
  end

  describe "CachexCache" do
    setup do
      Application.ensure_all_started(:cachex)
      {:ok, _pid} = Cachex.start_link(:vatchex_vies, limit: 100)
      :ok
    end

    test "get/2 returns cached value" do
      Cachex.put(:vatchex_vies, "test_key", %{cached: true}, expiration: :timer.seconds(60))
      assert {:ok, %{cached: true}} = VatchexVies.CachexCache.get(:vatchex_vies, "test_key")
    end

    test "get/2 returns :miss for missing key" do
      assert :miss = VatchexVies.CachexCache.get(:vatchex_vies, "nonexistent")
    end

    test "put/3 stores value in cache" do
      VatchexVies.CachexCache.put(:vatchex_vies, "test_key", %{stored: true})
      assert {:ok, %{stored: true}} = Cachex.get(:vatchex_vies, "test_key")
    end
  end
end
