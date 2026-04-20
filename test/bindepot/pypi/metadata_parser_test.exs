defmodule Bindepot.Pypi.MetadataParserTest do
  use ExUnit.Case, async: true

  alias Bindepot.Pypi.MetadataParser

  describe "metadata_parser" do
    test "parse_metadata" do
      metadata = ~S"Metadata-Version: 2.1
Name: pydemo02
Version: 0.1.0
Summary: A minimalistic Python project using setup.cfg only
Home-page: UNKNOWN
Author: Your Name
Author-email: UNKNOWN
License: MIT
Platform: UNKNOWN
Requires-Dist: requests

UNKNOWN


"

      md = MetadataParser.parse_metadata(metadata)
      assert [{"Name", "pydemo02"}] == md
    end
  end
end
