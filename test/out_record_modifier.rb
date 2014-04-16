require 'fluent/test'
require 'fluent/plugin/out_record_modifier'


class RecordModifierOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
    type record_modifier
    tag foo.filtered

    gen_host ${hostname}
    foo bar
    include_tag_key
    tag_key included_tag
    remove_keys hoge
  ]

  def create_driver(conf = CONFIG)
    Fluent::Test::OutputTestDriver.new(Fluent::RecordModifierOutput, tag='test_tag').configure(conf)
  end

  def get_hostname
    require 'socket'
    Socket.gethostname.chomp
  end

  def test_configure
    d = create_driver
    map = d.instance.instance_variable_get(:@map)

    assert_equal get_hostname, map['gen_host']
    assert_equal 'bar', map['foo']
  end

  def test_format
    d = create_driver

    d.run do
      d.emit("a" => 1)
      d.emit("a" => 2)
    end

    mapped = {'gen_host' => get_hostname, 'foo' => 'bar', 'included_tag' => 'test_tag'}
    assert_equal [
      {"a" => 1}.merge(mapped),
      {"a" => 2}.merge(mapped),
    ], d.records
  end

  def test_set_char_encoding
    d = create_driver %[
      type record_modifier

      tag foo.filtered
      char_encoding utf-8
    ]


    d.run do
      d.emit("k" => 'v'.force_encoding('BINARY'))
    end

    assert_equal [{"k" => 'v'.force_encoding('UTF-8')}], d.records
  end

  def test_convert_char_encoding
    d = create_driver %[
      type record_modifier

      tag foo.filtered
      char_encoding utf-8:cp932
    ]

    d.run do
      d.emit("k" => 'v'.force_encoding('utf-8'))
    end

    assert_equal [{"k" => 'v'.force_encoding('cp932')}], d.records
  end

  def test_remove_one_key
    d = create_driver %[
      type record_modifier

      tag foo.filtered
      remove_keys k1
    ]

    d.run do
      d.emit("k1" => 'v', "k2" => 'v')
    end

    assert_equal [{"k2" => 'v'}], d.records
  end

  def test_remove_multiple_keys
    d = create_driver %[
      type record_modifier

      tag foo.filtered
      remove_keys k1, k2, k3
    ]

    d.run do
      d.emit("k1" => 'v', "k2" => 'v', "k4" => 'v')
    end

    assert_equal [{"k4" => 'v'}], d.records
  end
end
