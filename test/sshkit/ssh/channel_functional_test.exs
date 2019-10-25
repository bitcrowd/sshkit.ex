defmodule SSHKit.SSH.ChannelFunctionalTest do
  @moduledoc false

  use SSHKit.FunctionalCase, async: true

  @bootconf [user: "me", password: "pass"]

  describe "Channel.subsystem/3" do
    @tag boot: [@bootconf]
    test "with user", %{hosts: [host]} do
      {:ok, conn} = SSHKit.SSH.connect(host.name, host.options)
      {:ok, channel} = SSHKit.SSH.Channel.open(conn)
      :success = SSHKit.SSH.Channel.subsystem(channel, "greeting-subsystem")

      SSHKit.SSH.Channel.send(channel, "Lorem\n")

      [welcome_message, response_message, _] = get_messages(channel)

      assert welcome_message == "Hello, who am I talking to?"
      assert response_message == "It's nice to meet you Lorem"
    end
  end

  defp get_messages(channel, message \\ "") do
    {:ok, {:data, _channel, _type, next_line}} = SSHKit.SSH.Channel.recv(channel)

    if String.ends_with?(next_line, "Lorem\n") do
      String.split("#{message}#{next_line}", "\n")
    else
      get_messages(channel, "#{message}#{next_line}")
    end
  end
end
