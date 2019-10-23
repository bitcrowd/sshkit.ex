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
      {:ok, {:data, _channel, _type, welcome_message}} = SSHKit.SSH.Channel.recv(channel)
      {:ok, {:data, _channel, _type, response_message}} = SSHKit.SSH.Channel.recv(channel)

      assert welcome_message == "Hello, who am I talking to?\n"
      assert response_message == "It's nice to meet you Lorem\n"
    end
  end
end
