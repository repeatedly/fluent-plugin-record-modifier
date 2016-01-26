require 'fluent/mixin/config_placeholders'

module Fluent
  class RecordModifierFilter < Filter
    Fluent::Plugin.register_filter('record_modifier', self)

    config_param :char_encoding, :string, :default => nil
    config_param :remove_keys, :string, :default => nil

    include Fluent::Mixin::ConfigPlaceholders

    BUILTIN_CONFIGURATIONS = %W(type @type log_level @log_level id @id char_encoding remove_keys)

    def configure(conf)
      super

      if conf.has_key?('include_tag_key')
        raise ConfigError, "include_tag_key and tag_key parameters are removed. Use 'tag ${tag}' in <record> section"
      end

      @map = {}
      conf.each_pair { |k, v|
        unless BUILTIN_CONFIGURATIONS.include?(k)
          conf.has_key?(k)
          $log.warn "top level definition is deprecated. Please put parameters inside <record>: '#{k} #{v}'"
          @map[k] = DynamicExpander.new(k, v)
        end
      }

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
          @map[k] = DynamicExpander.new(k, v)
        end
      end

      if @remove_keys
        @remove_keys = @remove_keys.split(',').map { |e| e.strip }
      end

      # Collect DynamicExpander related garbage instructions
      GC.start
    end

    def filter_stream(tag, es)
      new_es = MultiEventStream.new
      tag_parts = @has_tag_parts ? tag.split('.') : nil

      es.each { |time, record|
        @map.each_pair { |k, v|
          record[k] = v.expand(tag, time, record, tag_parts)
        }

        if @remove_keys
          @remove_keys.each { |v|
            record.delete(v)
          }
        end

        record = change_encoding(record) if @char_encoding
        new_es.add(time, record)
      }
      new_es
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
  end if defined?(Filter)
end
