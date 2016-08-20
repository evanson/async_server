defmodule AsyncServer.Util do
  @moduledoc """
  Utility functions
  """
  def ip_addr_to_string({octet_a, octet_b, octet_c, octet_d}) do
    to_string(octet_a) <> "." <> to_string(octet_b) <> "." <>
      to_string(octet_c) <> "." <> to_string(octet_d)
  end
end
