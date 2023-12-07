require 'fluent/plugin/filter'

module Fluent
  class Plugin::RecordModifierFilter < Plugin::Filter
    Fluent::Plugin.register_filter('record_modifier', self)

    helpers :record_accessor

    config_param :prepare_value, :string, default: nil,
                 desc: <<-DESC
Prepare values for filtering in configure phase. Prepared values can be used in <record>.
You can write any ruby code.
DESC
    config_param :char_encoding, :string, default: nil,
                 desc: <<-DESC
Fluentd including some plugins treats the logs as a BINARY by default to forward.
But an user sometimes processes the logs depends on their requirements,
e.g. handling char encoding correctly.
In more detail, please refer this section:
https://github.com/repeatedly/fluent-plugin-record-modifier#char_encoding.
DESC
    config_param :remove_keys, :array, default: nil,
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

    config_section :replace, param_name: :replaces, multi: true do
      desc "The field name to which the regular expression is applied"
      config_param :key, :string
      desc "The regular expression"
      config_param :expression do |value|
        if value.start_with?("/") && value.end_with?("/")
          Regexp.compile(value[1..-2])
        else
          $log.warn "You should use \"pattern /#{value}/\" instead of \"pattern #{value}\""
          Regexp.compile(value)
        end
      end
      desc "The replacement string"
      config_param :replace, :string
    end

    def configure(conf)
      super

      @map = {}
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
          element.has_key?(k) # to suppress unread configuration warning
          @has_tag_parts = true if v.include?('tag_parts')
          @map[k] = DynamicExpander.new(k, v, @prepare_value)
        end
      end

      if @remove_keys and @whitelist_keys
        raise Fluent::ConfigError, "remove_keys and whitelist_keys are exclusive with each other."
      elsif @remove_keys
        @remove_keys = @remove_keys.map { |key|
          record_accessor_create(key)
        }
      elsif @whitelist_keys
        @whitelist_keys = @whitelist_keys.split(',').map(&:strip)
        @whitelist_keys.concat(@map.keys).uniq!
      end

      # Collect DynamicExpander related garbage instructions
      GC.start
    end

    def filter(tag, time, record)
      tag_parts = @has_tag_parts ? tag.split('.') : nil

      @map.each_pair { |k, v|
        begin
          record[k] = v.expand(tag, time, record, tag_parts)
        rescue
          $log.error("filter_record_modifier::filter - exception in expression: '#{v.getcode}'")
          raise
        end
      }

      if @remove_keys
        @remove_keys.each { |ra|
          ra.delete(record)
        }
      elsif @whitelist_keys
        modified = {}
        @whitelist_keys.each do |key|
          modified[key] = record[key] if record.has_key?(key)
        end
        record = modified
      end

      unless @replaces.empty?
        @replaces.each { |replace|
          target_key = replace.key
          if record.include?(target_key) && replace.expression.match(record[target_key])
            record[target_key] = record[target_key].gsub(replace.expression, replace.replace)
          end
        }
      end

      record = change_encoding(record) if @char_encoding
      record
    end

    private

    def set_encoding(value)
      if value.is_a?(String)
        value.force_encoding(@from_enc)
      elsif value.is_a?(Hash)
        value.each_pair { |k, v|
          if v.frozen? && v.is_a?(String)
            value[k] = set_encoding(v.dup)
          else
            set_encoding(v)
          end
        }
      elsif value.is_a?(Array)
        value.each { |v| set_encoding(v) }
      else
        value
      end
    end

    def convert_encoding(value)
      if value.is_a?(String)
        value.force_encoding(@from_enc) if value.encoding == Encoding::BINARY
        value.encode!(@to_enc, @from_enc, :invalid => :replace, :undef => :replace)
      elsif value.is_a?(Hash)
        value.each_pair { |k, v|
          if v.frozen? && v.is_a?(String)
            value[k] = convert_encoding(v.dup)
          else
            convert_encoding(v)
          end
        }
      elsif value.is_a?(Array)
        value.each { |v| convert_encoding(v) }
      else
        value
      end
    end

    class DynamicExpander
      def getcode()
        @code
      end

      def initialize(param_key, param_value, prepare_value)
        if param_value.include?('${')
          __str_eval_code__ = parse_parameter(param_value)

          @code=__str_eval_code__

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
          eval prepare_value if prepare_value
        rescue SyntaxError
          raise ConfigError, "Pass invalid syntax parameter : key = prepare_value, value = #{prepare_value}"
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
