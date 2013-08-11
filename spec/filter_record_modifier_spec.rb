$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rspec'
require 'fluentd'
require 'fluentd/plugin_spec_helper'
require 'fluentd/plugin/filter_record_modifier'

Fluentd.setup!

include Fluentd::PluginSpecHelper

describe Fluentd::Plugin::RecordModifierFilter do
  let(:default_config) {
    %[
      type record_modifier
      gen_host ${Socket.gethostname.chomp}
      foo bar
      include_tag_key true
      tag_key included_tag
      include_time_key true
      time_as_epoch true
    ]
  }

  def create_driver(conf = default_config)
    generate_driver(Fluentd::Plugin::RecordModifierFilter, conf)
  end

  def get_hostname
    require 'socket'
    Socket.gethostname.chomp
  end

  it 'test_configure' do
    d = create_driver
    adders = d.instance.instance_variable_get(:@adders)

    expect(adders['gen_host']).to eql(get_hostname)
    expect(adders['foo']).to eql('bar')
    expect(d.instance.include_tag_key).to be_true
  end

  it 'test_format' do
    tag = 'tag'
    time = Time.now.to_i
    d = create_driver
    d.run { |d|
      d.with(tag, time) { |d|
        d.pitch("a" => 1)
        d.pitch("a" => 2)
      }
    }

    mapped = {'gen_host' => get_hostname, 'foo' => 'bar', 'included_tag' => tag, 'time' => time}
    expect(d.events['tag'].map { |e| e.record }).to eql([
      {"a" => 1}.merge(mapped),
      {"a" => 2}.merge(mapped),
    ])
  end
end
