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
  ]

  def create_driver(conf = CONFIG)
    Fluent::Test::OutputTestDriver.new(Fluent::RecordModifierOutput).configure(conf)
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

    mapped = {'gen_host' => get_hostname, 'foo' => 'bar'}
    assert_equal [
      {"a" => 1}.merge(mapped),
      {"a" => 2}.merge(mapped),
    ], d.records
  end
end
