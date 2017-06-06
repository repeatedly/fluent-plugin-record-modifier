require 'fluent/plugin/output'

module Fluent
  class Plugin::RecordModifierOutput < Plugin::Output
    Fluent::Plugin.register_output('record_modifier', self)

    helpers :event_emitter, :compat_parameters, :inject

    config_param :tag, :string,
                 desc: "The output record tag name."
    config_param :char_encoding, :string, default: nil,
                 desc: <<-DESC
Fluentd including some plugins treats the logs as a BINARY by default to forward.
But an user sometimes processes the logs depends on their requirements,
e.g. handling char encoding correctly.
In more detail, please refer this section:
https://github.com/repeatedly/fluent-plugin-record-modifier#char_encoding.
DESC

    config_param :remove_keys, :string, default: nil,
                 desc: <<-DESC
The logs include needless record keys in some cases.
You can remove it by using `remove_keys` parameter.
This option is exclusive with `whitelist_keys`.
DESC

    config_param :whitelist_keys, :string, default: nil,
                 desc: <<-DESC
Specify `whitelist_keys` to remove all unexpected keys and values from events.
Modified events will have only specified keys (if exist in original events).
This option is exclusive with `remove_keys`.
DESC

    BUILTIN_CONFIGURATIONS = %W(type tag include_tag_key tag_key char_encoding remove_keys whitelist_keys)

    def configure(conf)
      compat_parameters_convert(conf, :buffer, :inject)
      super

      @map = {}
      conf.each_pair { |k, v|
        unless BUILTIN_CONFIGURATIONS.include?(k)
          check_config_placeholders(k, v)
          conf.has_key?(k)
          @map[k] = v
        end
      }

      @to_enc = nil
      if @char_encoding
        from, to = @char_encoding.split(':', 2)
        @from_enc = Encoding.find(from)
        @to_enc = Encoding.find(to) if to

        m = if @to_enc
              method(:convert_encoding)
            else
              method(:set_encoding)
            end

        (class << self; self; end).module_eval do
          define_method(:change_encoding, m)
        end
      end

      if @remove_keys and @whitelist_keys
        raise Fluent::ConfigError, "remove_keys and whitelist_keys are exclusive with each other."
      elsif @remove_keys
        @remove_keys = @remove_keys.split(',').map(&:strip)
      elsif @whitelist_keys
        @whitelist_keys = @whitelist_keys.split(',').map(&:strip)
      end
    end

    def process(tag, es)
      stream = MultiEventStream.new
      es.each { |time, record|
        record = inject_values_to_record(tag, time, record)
        stream.add(time, modify_record(record))
      }
      router.emit_stream(@tag, stream)
    end

    private

    HOSTNAME_PLACEHOLDERS = %W(__HOSTNAME__ ${hostname})

    def check_config_placeholders(k, v)
      HOSTNAME_PLACEHOLDERS.each { |ph|
        if v.include?(ph)
          raise ConfigError, %!#{ph} placeholder in #{k} is removed. Use "\#{Socket.gethostname}" instead.!
        end
      }
    end

    def modify_record(record)
      @map.each_pair { |k, v|
        record[k] = v
      }

      if @remove_keys
        @remove_keys.each { |v|
          record.delete(v)
        }
      elsif @whitelist_keys
        modified = {}
        record.each do |k, v|
          modified[k] = v if @whitelist_keys.include?(k)
        end
        record = modified
      end

      record = change_encoding(record) if @char_encoding
      record
    end

    def set_encoding(record)
      record.each_pair { |k, v|
        if v.is_a?(String)
          v.force_encoding(@from_enc)
        end
      }
    end

    def convert_encoding(record)
      record.each_pair { |k, v|
        if v.is_a?(String)
          v.force_encoding(@from_enc) if v.encoding == Encoding::BINARY
          v.encode!(@to_enc, @from_enc, :invalid => :replace, :undef => :replace)
        end
      }
    end
  end
end
