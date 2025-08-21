defmodule SSHKit.UtilsTest do
  use ExUnit.Case, async: true

  alias SSHKit.Utils

  describe "charlistify/1" do
    test "converts binaries to char lists" do
      assert Utils.charlistify("sshkit") == ~c"sshkit"
    end

    test "converts binaries in tuples" do
      assert Utils.charlistify({:user, "me"}) == {:user, ~c"me"}
    end

    test "converts binaries in lists" do
      assert Utils.charlistify(["ssh-rsa", "ssh-dss"]) == [~c"ssh-rsa", ~c"ssh-dss"]
    end

    test "converts binaries in keywords" do
      assert Utils.charlistify(inet: :inet6, user: "me") == [inet: :inet6, user: ~c"me"]
    end

    test "converts binaries in nested lists" do
      actual = Utils.charlistify(pref_public_key_algs: ["ssh-rsa", "ssh-dss"])
      expected = [pref_public_key_algs: [~c"ssh-rsa", ~c"ssh-dss"]]
      assert actual == expected
    end

    test "converts binaries in nested keywords" do
      ciphers = [client2server: ["aes128-ctr"], server2client: ["aes128-cbc", "3des-cbc"]]
      actual = Utils.charlistify(preferred_algorithms: [cipher: ciphers])
      expected = [preferred_algorithms: [cipher: Utils.charlistify(ciphers)]]
      assert actual == expected
    end
  end
end
