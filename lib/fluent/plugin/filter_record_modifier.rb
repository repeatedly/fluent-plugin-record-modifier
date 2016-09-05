require 'fluent/plugin/filter'

module Fluent
  class Plugin::RecordModifierFilter < Plugin::Filter
    Fluent::Plugin.register_filter('record_modifier', self)

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

    BUILTIN_CONFIGURATIONS = %W(type @type log_level @log_level id @id char_encoding remove_keys whitelist_keys)

    def configure(conf)
      super

      if conf.has_key?('include_tag_key')
        raise ConfigError, "include_tag_key and tag_key parameters are removed. Use 'tag ${tag}' in <record> section"
      end

      @map = {}
      conf.each_pair { |k, v|
        unless BUILTIN_CONFIGURATIONS.include?(k)
          check_config_placeholders(k, v);
          conf.has_key?(k)
          $log.warn "top level definition is deprecated. Please put parameters inside <record>: '#{k} #{v}'"
          @map[k] = DynamicExpander.new(k, v)
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

      @has_tag_parts = false
      conf.elements.select { |element| element.name == 'record' }.each do |element|
        element.each_pair do |k, v|
          check_config_placeholders(k, v)
          element.has_key?(k) # to suppress unread configuration warning
          @has_tag_parts = true if v.include?('tag_parts')
          @map[k] = DynamicExpander.new(k, v)
        end
      end

      if @remove_keys and @whitelist_keys
        raise Fluent::ConfigError, "remove_keys and whitelist_keys are exclusive with each other."
      elsif @remove_keys
        @remove_keys = @remove_keys.split(',').map(&:strip)
      elsif @whitelist_keys
        @whitelist_keys = @whitelist_keys.split(',').map(&:strip)
      end

      # Collect DynamicExpander related garbage instructions
      GC.start
    end

    def filter(tag, time, record)
      tag_parts = @has_tag_parts ? tag.split('.') : nil

      @map.each_pair { |k, v|
        record[k] = v.expand(tag, time, record, tag_parts)
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

    private

    def set_encoding(value)
      if value.is_a?(String)
        value.force_encoding(@from_enc)
      elsif value.is_a?(Hash)
        value.each_pair { |k, v| set_encoding(v) }
      elsif value.is_a?(Array)
        value.each { |v| set_encoding(v) }
      end
    end

    def convert_encoding(value)
      if value.is_a?(String)
        value.force_encoding(@from_enc) if value.encoding == Encoding::BINARY
        value.encode!(@to_enc, @from_enc, :invalid => :replace, :undef => :replace)
      elsif value.is_a?(Hash)
        value.each_pair { |k, v| convert_encoding(v) }
      elsif value.is_a?(Array)
        value.each { |v| convert_encoding(v) }
      end
    end

    HOSTNAME_PLACEHOLDERS = %W(__HOSTNAME__ ${hostname})

    def check_config_placeholders(k, v)
      HOSTNAME_PLACEHOLDERS.each { |ph|
        if v.include?(ph)
          raise ConfigError, %!#{ph} placeholder in #{k} is removed. Use "\#{Socket.gethostname}" instead.!
        end
      }
    end

    class DynamicExpander
      def initialize(param_key, param_value)
        if param_value.include?('${')
          __str_eval_code__ = parse_parameter(param_value)

          # Use class_eval with string instead of define_method for performance.
          # It can't share instructions but this is 2x+ faster than define_method in filter case.
          # Refer: http://tenderlovemaking.com/2013/03/03/dynamic_method_definitions.html
          (class << self; self; end).class_eval <<-EORUBY,  __FILE__, __LINE__ + 1
            def expand(tag, time, record, tag_parts)
              #{__str_eval_code__}
            end
          EORUBY
        else
          @param_value = param_value
        end

        begin
          # check eval genarates wrong code or not
          expand(nil, nil, nil, nil)
        rescue SyntaxError
          raise ConfigError, "Pass invalid syntax parameter : key = #{param_key}, value = #{param_value}"
        rescue
          # Ignore other runtime errors
        end
      end

      # Default implementation for fixed value. This is overwritten when parameter contains '${xxx}' placeholder
      def expand(tag, time, record, tag_parts)
        @param_value
      end

      private

      def parse_parameter(value)
        num_placeholders = value.scan('${').size
        if num_placeholders == 1
          if value.start_with?('${') && value.end_with?('}')
            return value[2..-2]
          else
            "\"#{value.gsub('${', '#{')}\""
          end
        else
          "\"#{value.gsub('${', '#{')}\""
        end
      end
    end
  end
end
