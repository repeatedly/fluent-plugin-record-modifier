require 'fluent/mixin/config_placeholders'

module Fluent
  class RecordModifierOutput < Output
    Fluent::Plugin.register_output('record_modifier', self)

    config_param :tag, :string
    config_param :char_encoding, :string, :default => nil
    config_param :remove_fields, :string, :default => nil

    include SetTagKeyMixin
    include Fluent::Mixin::ConfigPlaceholders

    BUILTIN_CONFIGURATIONS = %W(type tag include_tag_key tag_key char_encoding remove_fields)

    def configure(conf)
      super

      @map = {}
      conf.each_pair { |k, v|
        unless BUILTIN_CONFIGURATIONS.include?(k)
          conf.has_key?(k)
          @map[k] = v
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

      @remove_fields = if @remove_fields then @remove_fields.split(',').map {|e| e.strip } else [] end
    end

    def emit(tag, es, chain)
      es.each { |time, record|
        filter_record(tag, time, record)
        Engine.emit(@tag, time, modify_record(record))
      }

      chain.next
    end

    private

    def modify_record(record)
      @map.each_pair { |k, v|
        record[k] = v
      }

      @remove_fields.each { |v|
        record.delete(v)
      }

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
