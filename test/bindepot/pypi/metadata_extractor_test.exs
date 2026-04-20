defmodule Bindepot.Pypi.MetadataExtractorTest do
  use ExUnit.Case, async: true

  alias Bindepot.Pypi.MetadataExtractor

  describe "metadata_extractor" do
    test "extract_from_wheel" do
      expected_metadata = ~S"Metadata-Version: 2.1
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

      p = Path.join([__DIR__, "../../data", "pydemo02-0.1.0-py3-none-any.whl"])
      md = MetadataExtractor.extract_wheel_metadata(p)
      assert {:ok, expected_metadata} == md
    end
  end
end
