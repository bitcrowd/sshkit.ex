defmodule SSHKit.SCP.CommandTest do
  use ExUnit.Case, async: true

  import SSHKit.Utils, only: [shellescape: 1]
  import SSHKit.SCP.Command, only: [build: 3]

  @path "/home/test/code"
  @escaped shellescape(@path)

  describe "build/3 (:upload)" do
    test "constructs basic upload commands" do
      assert build(:upload, @path, []) == "scp -t #{@escaped}"
    end

    test "constructs verbose upload commands" do
      assert build(:upload, @path, verbose: true) == "scp -t -v #{@escaped}"
    end

    test "constructs preserving upload commands" do
      assert build(:upload, @path, preserve: true) == "scp -t -p #{@escaped}"
    end

    test "constructs recursive upload commands" do
      assert build(:upload, @path, recursive: true) == "scp -t -r #{@escaped}"
    end

    test "constructs verbose and preserving upload commands" do
      assert build(:upload, @path, verbose: true, preserve: true) == "scp -t -v -p #{@escaped}"
    end

    test "constructs verbose and recursive upload commands" do
      assert build(:upload, @path, verbose: true, recursive: true) == "scp -t -v -r #{@escaped}"
    end

    test "constructs preserving and recursive upload commands" do
      assert build(:upload, @path, preserve: true, recursive: true) == "scp -t -p -r #{@escaped}"
    end
  end

  describe "build/3 (:download)" do
    test "constructs basic download commands" do
      assert build(:download, @path, []) == "scp -f #{@escaped}"
    end

    test "constructs verbose download commands" do
      assert build(:download, @path, verbose: true) == "scp -f -v #{@escaped}"
    end

    test "constructs preserving download commands" do
      assert build(:download, @path, preserve: true) == "scp -f -p #{@escaped}"
    end

    test "constructs recursive download commands" do
      assert build(:download, @path, recursive: true) == "scp -f -r #{@escaped}"
    end

    test "constructs verbose and preserving download commands" do
      assert build(:download, @path, verbose: true, preserve: true) == "scp -f -v -p #{@escaped}"
    end

    test "constructs verbose and recursive download commands" do
      assert build(:download, @path, verbose: true, recursive: true) == "scp -f -v -r #{@escaped}"
    end

    test "constructs preserving and recursive download commands" do
      assert build(:download, @path, preserve: true, recursive: true) == "scp -f -p -r #{@escaped}"
    end
  end
end
