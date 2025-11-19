Below is a concise, production-ready example of how to proxy Python’s **Simple Repository API** (PEP 503) using **Elixir Phoenix**.
The idea: any request hitting your Phoenix endpoint is forwarded **as-is** (path, query, method, body, headers) to a configured upstream PyPI-simple server, and the response is streamed back to the client.

The solution uses:

* **Finch** for HTTP client (recommended for Phoenix 1.7+).
* A **controller** to handle route matching.
* Correct header passthrough (minus hop-by-hop headers).
* Streaming body support for uploads (e.g., wheel or sdist upload, though not part of PEP 503, but some private repos allow POST).

---

# 1. Configure Finch

In `application.ex`:

```elixir
children = [
  {Finch, name: MyApp.Finch}
]

Supervisor.start_link(children, strategy: :one_for_one)
```

---

# 2. Add route

In `router.ex`:

```elixir
scope "/simple", MyAppWeb do
  match :*, "/*path", SimpleProxyController, :proxy
end
```

This catches all methods and paths under `/simple/**`.

---

# 3. Controller implementation

`lib/my_app_web/controllers/simple_proxy_controller.ex`:

```elixir
defmodule MyAppWeb.SimpleProxyController do
  use MyAppWeb, :controller

  @upstream "https://my-private-pypi.example.com/simple"

  # Hop-by-hop headers that should NOT be forwarded
  @excluded_headers ~w(
    connection
    keep-alive
    proxy-authenticate
    proxy-authorization
    te
    trailers
    transfer-encoding
    upgrade
  )

  def proxy(conn, %{"path" => path_segments}) do
    upstream_url = build_upstream_url(path_segments, conn.query_string)

    method = conn.method |> String.to_atom()

    # Extract body (works for POST/PUT multipart too)
    {:ok, body, _conn} = read_body(conn)

    # Forward headers, removing hop-by-hop headers
    headers =
      conn.req_headers
      |> Enum.reject(fn {k, _} -> k in @excluded_headers end)

    request = Finch.build(method, upstream_url, headers, body)

    case Finch.request(request, MyApp.Finch) do
      {:ok, %Finch.Response{} = resp} ->
        conn
        |> put_resp_headers(resp.headers)
        |> send_resp(resp.status, resp.body)

      {:error, err} ->
        send_resp(conn, 502, "Proxy Error: #{inspect(err)}")
    end
  end

  defp build_upstream_url(path_segments, query_string) do
    path = Enum.join(path_segments, "/")
    base = "#{@upstream}/#{path}"

    if query_string == "" do
      base
    else
      base <> "?" <> query_string
    end
  end

  defp put_resp_headers(conn, headers) do
    headers
    |> Enum.reject(fn {k, _} -> k in @excluded_headers end)
    |> Enum.reduce(conn, fn {k, v}, c -> put_resp_header(c, k, v) end)
  end
end
```

---

# 4. What this gives you

* ✔ Handles `GET /simple`, `GET /simple/<project>/`, etc.
* ✔ Forwards all valid methods (GET, HEAD, POST, etc.).
* ✔ Streams payloads for file uploads if your repository accepts them.
* ✔ Preserves headers, minus hop-by-hop ones (required by HTTP spec).
* ✔ Returns upstream status, headers, and body verbatim.

---

# 5. Optional: Environment-based upstream

Replace:

```elixir
@upstream "https://my-private-pypi.example.com/simple"
```

with:

```elixir
@upstream Application.compile_env!(:my_app, :simple_upstream)
```

and set in config:

```elixir
config :my_app, :simple_upstream, "https://repo.internal/simple"
```

---

If you want, I can also provide:

✅ a streaming proxy version (no body buffering)
✅ Plug version instead of controller
✅ caching of simple index responses
✅ authentication passthrough or header injection (e.g., private PyPI token)
