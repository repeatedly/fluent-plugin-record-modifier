require 'fluent/test/driver/output'
require 'fluent/plugin/out_record_modifier'


class RecordModifierOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = %q!
    type record_modifier
    tag foo.filtered

    gen_host "#{Socket.gethostname}"
    foo bar
    include_tag_key
    tag_key included_tag
    remove_keys hoge
  !

  def create_driver(conf = CONFIG)
    Fluent::Test::Driver::Output.new(Fluent::Plugin::RecordModifierOutput).configure(conf)
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

    d.run(default_tag: 'test_tag') do
      d.feed({"a" => 1})
      d.feed({"a" => 2})
    end

    mapped = {'gen_host' => get_hostname, 'foo' => 'bar', 'included_tag' => 'test_tag'}
    assert_equal [
      {"a" => 1}.merge(mapped),
      {"a" => 2}.merge(mapped),
    ], d.events.map { |e| e.last }
  end

  def test_set_char_encoding
    d = create_driver %[
      type record_modifier

      tag foo.filtered
      char_encoding utf-8
    ]

    d.run(default_tag: 'test_tag') do
      d.feed({"k" => 'v'.force_encoding('BINARY')})
    end

    assert_equal [{"k" => 'v'.force_encoding('UTF-8')}], d.events.map { |e| e.last }
  end

  def test_convert_char_encoding
    d = create_driver %[
      type record_modifier

      tag foo.filtered
      char_encoding utf-8:cp932
    ]

    d.run(default_tag: 'test_tag') do
      d.feed("k" => 'v'.force_encoding('utf-8'))
    end

    assert_equal [{"k" => 'v'.force_encoding('cp932')}], d.events.map { |e| e.last }
  end

  def test_remove_one_key
    d = create_driver %[
      type record_modifier

      tag foo.filtered
      remove_keys k1
    ]

    d.run(default_tag: 'test_tag') do
      d.feed({"k1" => 'v', "k2" => 'v'})
    end

    assert_equal [{"k2" => 'v'}], d.events.map { |e| e.last }
  end

  def test_remove_multiple_keys
    d = create_driver %[
      type record_modifier

      tag foo.filtered
      remove_keys k1, k2, k3
    ]

    d.run(default_tag: 'test_tag') do
      d.feed({"k1" => 'v', "k2" => 'v', "k4" => 'v'})
    end

    assert_equal [{"k4" => 'v'}], d.events.map { |e| e.last }
  end

  def test_remove_non_whitelist_keys
    d = create_driver %[
      type record_modifier

      tag foo.filtered
      whitelist_keys k1, k2, k3
    ]

    d.run(default_tag: 'test_tag') do
      d.feed({"k1" => 'v', "k2" => 'v', "k4" => 'v', "k5" => 'v'})
    end

    assert_equal [{"k1" => 'v', "k2" => 'v'}], d.events.map { |e| e.last }
  end
end
