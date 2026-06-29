# SPDX-FileCopyrightText: 2026 Isaak Tsalicoglou <isaak@waseigo.com>
# SPDX-License-Identifier: Apache-2.0

defmodule VatchexViesTest do
  use ExUnit.Case

  alias VatchexVies

  @valid_response %{
    countryCode: "EL",
    vatNumber: "998144460",
    valid: true,
    name: "ΟΝΟΜΑΣΙΑ ΕΤΑΙΡΕΙΑΣ",
    tradingName: "ΕΠΩΝΥΜΙΑ",
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

      assert {:ok, result} =
               VatchexVies.lookup("EL", "998144460", test_adapter: {Req.Test, VatchexVies})

      assert result[:afm] == "998144460"
      assert result[:onomasia] == "ΟΝΟΜΑΣΙΑ ΕΤΑΙΡΕΙΑΣ"
      assert result[:commer_title] == "ΕΠΩΝΥΜΙΑ"
      assert result[:address] == "ΟΔΟΣ 10\nΑΘΗΝΑ"
      assert result[:address_collapsed] == "ΟΔΟΣ 10 ΑΘΗΝΑ"
      assert result[:country_code] == "EL"
      assert result[:source] == :vies
    end

    test "returns error for invalid VAT" do
      Req.Test.stub(VatchexVies, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(@invalid_response))
      end)

      assert {:error, %{code: :invalid_vat, descr: "Invalid VAT number"}} =
               VatchexVies.lookup("EL", "123456789", test_adapter: {Req.Test, VatchexVies})
    end

    test "returns error for empty VAT number without API call" do
      assert {:error, %{code: :invalid_vat, descr: "VAT number is blank"}} =
               VatchexVies.lookup("EL", "")
    end

    test "returns error for whitespace-only VAT number without API call" do
      assert {:error, %{code: :invalid_vat, descr: "VAT number is blank"}} =
               VatchexVies.lookup("EL", "   ")
    end

    test "returns error on transport failure" do
      Req.Test.stub(VatchexVies, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, %{code: :vies_request_failed}} =
               VatchexVies.lookup("EL", "998144460", test_adapter: {Req.Test, VatchexVies})
    end

    test "returns error on HTTP 500" do
      Req.Test.stub(VatchexVies, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "text/plain")
        |> Plug.Conn.resp(500, "Server Error")
      end)

      assert {:error, %{code: :vies_http_error, descr: "HTTP 500"}} =
               VatchexVies.lookup("EL", "998144460", test_adapter: {Req.Test, VatchexVies})
    end

    test "returns error on HTTP 429 rate limit" do
      Req.Test.stub(VatchexVies, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "text/plain")
        |> Plug.Conn.resp(429, "Too Many Requests")
      end)

      assert {:error, %{code: :vies_too_many_requests, descr: "Rate limited by VIES"}} =
               VatchexVies.lookup("EL", "998144460", test_adapter: {Req.Test, VatchexVies})
    end
  end

  describe "available_countries/0" do
    test "returns country map on success" do
      Req.Test.stub(VatchexVies, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(@status_response))
      end)

      assert {:ok, countries} =
               VatchexVies.available_countries(test_adapter: {Req.Test, VatchexVies})

      assert countries["EL"] == true
      assert countries["FR"] == false
    end

    test "returns error on failure" do
      Req.Test.stub(VatchexVies, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, %{code: :vies_status_unavailable}} =
               VatchexVies.available_countries(test_adapter: {Req.Test, VatchexVies})
    end
  end

  describe "available?/1" do
    test "returns true for available country" do
      Req.Test.stub(VatchexVies, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(@status_response))
      end)

      assert {:ok, true} = VatchexVies.available?("EL", test_adapter: {Req.Test, VatchexVies})
    end

    test "returns false for unavailable country" do
      Req.Test.stub(VatchexVies, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(@status_response))
      end)

      assert {:ok, false} = VatchexVies.available?("FR", test_adapter: {Req.Test, VatchexVies})
    end
  end

  describe "Cache protocol" do
    test "get on unknown module returns :miss" do
      assert :miss = VatchexVies.Cache.get(UnknownModule, "any_key")
    end

    test "put on unknown module silently returns :ok" do
      assert :ok = VatchexVies.Cache.put(UnknownModule, "key", %{val: 1}, [])
    end
  end

  describe "CachexCache" do
    setup do
      Application.ensure_all_started(:cachex)

      case Cachex.start_link(:vatchex_vies, limit: 100) do
        {:ok, _pid} -> :ok
        {:error, {:already_started, _pid}} -> :ok
      end
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

    test "end-to-end cache hit returns cached data without API call" do
      Req.Test.stub(VatchexVies, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(@valid_response))
      end)

      adapter = {Req.Test, VatchexVies}
      opts = [test_adapter: adapter, cache: VatchexVies.CachexCache]

      # First call hits the API
      assert {:ok, result} = VatchexVies.lookup("EL", "998144460", opts)
      assert result[:afm] == "998144460"

      # Second call should hit cache (not API) — same key, same result
      assert {:ok, ^result} = VatchexVies.lookup("EL", "998144460", opts)
    end
  end

  describe "process_name/process_address edge cases" do
    test "lookup handles missing name gracefully" do
      response = %{@valid_response | name: nil}

      Req.Test.stub(VatchexVies, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response))
      end)

      assert {:ok, result} =
               VatchexVies.lookup("EL", "998144460", test_adapter: {Req.Test, VatchexVies})

      assert result[:onomasia] == ""
    end

    test "lookup handles missing address gracefully" do
      response = %{@valid_response | address: nil}

      Req.Test.stub(VatchexVies, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response))
      end)

      assert {:ok, result} =
               VatchexVies.lookup("EL", "998144460", test_adapter: {Req.Test, VatchexVies})

      assert result[:address] == ""
      assert result[:address_collapsed] == ""
    end

    test "lookup handles multi-space name" do
      response = %{@valid_response | name: "  Company   Name  "}

      Req.Test.stub(VatchexVies, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response))
      end)

      assert {:ok, result} =
               VatchexVies.lookup("EL", "998144460", test_adapter: {Req.Test, VatchexVies})

      assert result[:onomasia] == "Company Name"
    end
  end

  describe "available_countries error handling" do
    test "returns error on non-200 status" do
      Req.Test.stub(VatchexVies, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "text/plain")
        |> Plug.Conn.resp(503, "Service Unavailable")
      end)

      assert {:error, %{code: :vies_status_unavailable}} =
               VatchexVies.available_countries(test_adapter: {Req.Test, VatchexVies})
    end
  end
end
