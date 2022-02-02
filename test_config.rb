require 'test/unit'
require 'lib/config'
require 'tmpdir'

module ExtraAsserts

  def assert_raise_with_message(klass, msg, &block)
    begin
      block.call()
    rescue klass => e
      if msg != e.to_s
        raise e
      end
    end
  end

end


class TestLoadConfig < Test::Unit::TestCase
  include ExtraAsserts

  def test_load()
    Dir.mktmpdir do |d|

      # File
      config_file = File.join(d, "a.yml")
      File.open(config_file, "w") do |f|
        f.write("a: true")
      end
      # Dir
      config_dir, = FileUtils.mkdir_p(File.join(d, "dir1"))
      File.open(File.join(config_dir, "b.yml"), "w") do |f|
        f.write("b: true")
      end
      File.open(File.join(config_dir, "c.yml"), "w") do |f|
        f.write("c: true")
      end
      # Hash
      config_hash = {
        'd' => true,
        'boxes' => {
          'box-a' => 'url-a'
        },
        'nodes' => {
          'a' => {'box' => 'box-a'},
          # No box
          'b' => {},
        }
      }

      all = load_config(config_file, config_dir, config_hash)
      assert(all == {
        'a' => true,
        'b' => true,
        'c' => true,
        'd' => true,
        'boxes' => {
          'box-a' => 'url-a'
        },
        'nodes' => {
          'a' => {
            'box' => 'box-a',
            'cpu' => 1,
            'memory' => 512
          },
        }
      })

    end
  end

  def test_no_nodes()
    err = "No nodes defined in configuration"
    assert_raise_with_message ConfigError, err do
      _ = load_config({})
    end
  end

  def test_bad_path()
    err = "Configuration file/directory doesn't exist: /foo/bar"
    assert_raise_with_message ConfigError, err do
      _ = load_config("/foo/bar")
    end
  end

  def test_bad_spec_type()
    err = "1 is not a valid configuration spec"
    assert_raise_with_message ConfigError, err do
      _ = load_config(1)
    end
  end

end


class TestParseConfigDir < Test::Unit::TestCase

  def test_dir()
    Dir.mktmpdir do |d|
      File.open(File.join(d, "a.yml"), "w") do |f|
        f.write("a: 1\nb: 2")
      end
      File.open(File.join(d, "b.yml"), "w") do |f|
        f.write("b: 3\nc: 4")
      end

      out = parse_config_dir(d)

      assert_equal(out['a'], 1)
      assert_equal(out['b'], 2)
      assert_equal(out['c'], 4)
    end
  end

end


class TestCreateDir < Test::Unit::TestCase
  include ExtraAsserts

  def test_success()
    Dir.mktmpdir do |d|
      path = File.join(d, "mydir")
      create_dir(path)
      assert_equal(File.directory?(path), true)
    end
  end

  def test_error()
    msg = "Unable to create path: /foo. Please ensure you have write permissions."
    assert_raise_with_message ConfigError, msg do
      create_dir("/foo")
    end
  end

end


class TestSetupUserConfig < Test::Unit::TestCase
  include ExtraAsserts

  $input_data = []

  def mock_input
    $input_data.shift
  end

  def test_create_code
    Dir.mktmpdir do |d|
      # Set up directories; initially no code folder
      user_dir, = FileUtils.mkdir_p(File.join(d, "user"))
      template_dir, = FileUtils.mkdir_p(File.join(d, "templates"))
      File.open(File.join(template_dir, "config.yml"), "w") do |f|
        f.write("code: __CODE__")
      end

      code_dir = File.join(user_dir, "code")
      # Include bad input; should retry
      $input_data = ["", code_dir, "foo", "yes"]

      ensure_user_config(user_dir, template_dir, method(:mock_input))

      # Check that all commands got consumed
      assert_equal($input_data, [])
      # Check if code directory exists
      assert_equal(File.directory?(code_dir), true)
    end
  end

  def test_abort
    Dir.mktmpdir do |d|
      user_dir, = FileUtils.mkdir_p(File.join(d, "user"))
      template_dir, = FileUtils.mkdir_p(File.join(d, "templates"))

      code_dir = File.join(user_dir, "code")
      $input_data = [code_dir, "no"]

      msg = "Quitting vagrant setup..."
      assert_raise_with_message ConfigError, msg do
        ensure_user_config(user_dir, template_dir, method(:mock_input))
      end

      # Check that all commands got consumed
      assert_equal($input_data, [])
    end
  end

  def test_bad_code_directory
    Dir.mktmpdir do |d|
      user_dir = "/user1234"
      template_dir, = FileUtils.mkdir_p(File.join(d, "templates"))

      code_dir = File.join(user_dir, "code")
      $input_data = [code_dir, "yes"]

      msg = "Unable to create path: /user1234/code. Please ensure you have write permissions."
      assert_raise_with_message ConfigError, msg do
        ensure_user_config(user_dir, template_dir, method(:mock_input))
      end
    end
  end

end
