defmodule Bindepot.PyPI.HtmlIndexParser do
  @moduledoc ~S"""
    Streaming-safe HTML <a> tag extractor using regular expressions.

    Extracts:
      * href attribute
      * anchor inner content
      * hash digest fragments (#sha256=...)
      * all tag attributes (optional convenience)

    Works on streamed HTML chunks with sliding window buffering.
  """

  # Match an <a ...>...</a> pair with:
  #  * arbitrary whitespace
  #  * arbitrary attribute order
  #  * arbitrary case
  #  * non-greedy inner match
  #
  # Captures:
  #   1: Full opening tag content (attributes only)
  #   2: Anchor inner content
  @tag_regex ~r/<a\s+([^>]*?)>(.*?)<\/a>/si

  # Extract all key="value" style attributes
  @attr_regex ~r/([a-zA-Z0-9:_-]+)\s*=\s*"([^"]*)"/

  # Extract fragment hashes like '#sha256=abcd'
  @hash_regex ~r/#([a-z0-9]+)=([A-Fa-f0-9]+)/

  # sliding window size (8 KB)
  @max_buffer 8192

  @doc """
  Stream-safe extraction of anchor tags.
  Returns:
    [
      %{
        href: "...",
        content: "...",
        attrs: %{...},
        hash: %{algo: ..., digest: ...} | nil
      },
      ...
    ]
  """
  def extract(stream) do
    stream
    |> Enum.reduce({[], ""}, fn chunk, {acc, buffer} ->
      buffer = buffer <> chunk
      {matches, rest} = extract_from_buffer(buffer)
      {[matches | acc], rest}
    end)
    |> elem(0)
    |> List.flatten()
    |> Enum.reverse()
  end

  #
  # Process the buffer:
  #  * Extract one <a>...</a> match at a time
  #  * Return remaining unconsumed tail
  #
  defp extract_from_buffer(buffer) do
    captures = Regex.scan(@tag_regex, buffer, return: :index)

    case captures do
      [] ->
        # Keep only the sliding tail of the buffer
        tail = sliding_tail(buffer)
        {[], tail}

      [_ | _] ->
        r =
          Enum.reduce(captures, {[], buffer, 0}, fn capture, {acc, buffer, off} ->
            [{start, len}, {tag_start, tag_len}, {content_start, content_len}] =
              capture

            tag_attrs = String.slice(buffer, tag_start - off, tag_len)
            content = String.slice(buffer, content_start - off, content_len)
            entry = extract_entry(tag_attrs, content)

            # Remaining buffer after this tag
            offset = start + len - off
            rest = String.slice(buffer, offset, byte_size(buffer) - offset)

            {[entry | acc], rest, offset}
          end)

        {elem(r, 0), elem(r, 1)}
    end
  end

  #
  # Extract relevant info from tag attributes and content
  #
  defp extract_entry(raw_attrs, content) do
    attrs =
      for [_, k, v] <- Regex.scan(@attr_regex, raw_attrs), into: %{} do
        {String.downcase(k), v}
      end

    {href, attrs} = Map.pop(attrs, "href")

    hash =
      case href do
        nil ->
          nil

        _ ->
          case Regex.run(@hash_regex, href) do
            [_, algo, digest] -> %{algo: algo, digest: digest}
            _ -> nil
          end
      end

    %{
      href: href,
      content: content,
      attrs: attrs,
      hash: hash
    }
  end

  #
  # Keep only the buffer tail to avoid growing forever
  #
  defp sliding_tail(buffer) when byte_size(buffer) <= @max_buffer do
    buffer
  end

  defp sliding_tail(buffer) do
    # Keep last @max_buffer bytes
    start = byte_size(buffer) - @max_buffer
    String.slice(buffer, start, @max_buffer)
  end
end
