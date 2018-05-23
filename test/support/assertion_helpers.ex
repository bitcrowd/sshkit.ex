defmodule SSHKit.AssertionHelpers do
  @moduledoc false

  def create_local_tmp_path do
    rand =
      16
      |> :crypto.strong_rand_bytes()
      |> Base.url_encode64()
      |> binary_part(0, 16)

    Path.join(System.tmp_dir(), "sshkit-test-#{rand}")
  end
end
