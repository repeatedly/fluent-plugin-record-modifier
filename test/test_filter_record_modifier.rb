require 'fluent/test'
require 'fluent/plugin/filter_record_modifier'
require 'test/unit'

exit unless defined?(Fluent::Filter)

class RecordModifierFilterTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
    @tag = 'test.tag'
  end

  CONFIG = %q!
    remove_keys hoge

    <record>
      gen_host "#{Socket.gethostname}"
      foo bar
      included_tag ${tag}
      tag_wrap -${tag_parts[0]}-${tag_parts[1]}-
    </record>
  !

  def create_driver(conf = CONFIG)
    Fluent::Test::FilterTestDriver.new(Fluent::RecordModifierFilter, @tag).configure(conf, true)
  end

  def get_hostname
    require 'socket'
    Socket.gethostname.chomp
  end

  def test_configure
    d = create_driver
    map = d.instance.instance_variable_get(:@map)

    map.each_pair { |k, v|
      assert v.is_a?(Fluent::RecordModifierFilter::DynamicExpander)
    }
  end

  def test_format
    d = create_driver

    d.run do
      d.emit("a" => 1)
      d.emit("a" => 2)
    end

    mapped = {'gen_host' => get_hostname, 'foo' => 'bar', 'included_tag' => @tag, 'tag_wrap' => "-#{@tag.split('.')[0]}-#{@tag.split('.')[1]}-"}
    assert_equal [
      {"a" => 1}.merge(mapped),
      {"a" => 2}.merge(mapped),
    ], d.filtered_as_array.map { |e| e.last }
  end

  def test_set_char_encoding
    d = create_driver %[
      char_encoding utf-8
    ]

    d.run do
      d.emit("k" => 'v'.force_encoding('BINARY'))
      d.emit("k" => %w(v ビ).map{|v| v.force_encoding('BINARY')})
      d.emit("k" => {"l" => 'ビ'.force_encoding('BINARY')})
    end

    assert_equal [
      {"k" => 'v'.force_encoding('UTF-8')},
      {"k" => %w(v ビ).map{|v| v.force_encoding('UTF-8')}},
      {"k" => {"l" => 'ビ'.force_encoding('UTF-8')}},
    ], d.filtered_as_array.map { |e| e.last }
  end

  def test_convert_char_encoding
    d = create_driver %[
      char_encoding utf-8:cp932
    ]

    d.run do
      d.emit("k" => 'v'.force_encoding('utf-8'))
      d.emit("k" => %w(v ビ).map{|v| v.force_encoding('utf-8')})
      d.emit("k" => {"l" => 'ビ'.force_encoding('utf-8')})
    end

    assert_equal [
      {"k" => 'v'.force_encoding('cp932')},
      {"k" => %w(v ビ).map{|v| v.encode!('cp932')}},
      {"k" => {"l" => 'ビ'.encode!('cp932')}},
    ], d.filtered_as_array.map { |e| e.last }
  end

  def test_remove_one_key
    d = create_driver %[
      remove_keys k1
    ]

    d.run do
      d.emit("k1" => 'v', "k2" => 'v')
    end

    assert_equal [{"k2" => 'v'}], d.filtered_as_array.map { |e| e.last }
  end

  def test_remove_multiple_keys
    d = create_driver %[
      remove_keys k1, k2, k3
    ]

    d.run do
      d.emit("k1" => 'v', "k2" => 'v', "k4" => 'v')
    end

    assert_equal [{"k4" => 'v'}], d.filtered_as_array.map { |e| e.last }
  end

  def test_remove_non_whitelist_keys
    d = create_driver %[
      whitelist_keys k1, k2, k3
    ]

    d.run do
      d.emit("k1" => 'v', "k2" => 'v', "k4" => 'v', "k5" => 'v')
    end

    assert_equal [{"k1" => 'v', "k2" => 'v'}], d.filtered_as_array.map(&:last)
  end

  sub_test_case 'frozen check' do
    def test_set_char_encoding
      d = create_driver %[
        char_encoding utf-8
      ]

      d.run do
        d.emit("k" => 'v'.force_encoding('BINARY').freeze, 'n' => 1)
        d.emit("k" => {"l" => 'v'.force_encoding('BINARY').freeze, 'n' => 1})
      end

      assert_equal [
        {"k" => 'v'.force_encoding('UTF-8'), 'n' => 1},
        {"k" => {"l" => 'v'.force_encoding('UTF-8'), 'n' => 1}},
      ], d.filtered_as_array.map { |e| e.last }
    end

    def test_convert_char_encoding
      d = create_driver %[
        char_encoding utf-8:cp932
      ]

      d.run do
        d.emit("k" => 'v'.force_encoding('utf-8').freeze, 'n' => 1)
        d.emit("k" => {"l" => 'v'.force_encoding('utf-8').freeze, 'n' => 1})
      end

      assert_equal [
        {"k" => 'v'.force_encoding('cp932'), 'n' => 1},
        {"k" => {"l" => 'v'.force_encoding('cp932'), 'n' => 1}},
      ], d.filtered_as_array.map { |e| e.last }
    end
  end
end
