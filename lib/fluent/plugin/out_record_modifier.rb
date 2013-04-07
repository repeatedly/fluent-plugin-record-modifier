require 'fluent/mixin/config_placeholders'

module Fluent
  class RecordModifierOutput < Output
    Fluent::Plugin.register_output('record_modifier', self)

    config_param :tag, :string

    include SetTagKeyMixin
    include Fluent::Mixin::ConfigPlaceholders

    BUILTIN_CONFIGURATIONS = %W(type tag include_tag_key tag_key)

    def configure(conf)
      super

      @map = {}
      conf.each_pair { |k, v|
        unless BUILTIN_CONFIGURATIONS.include?(k)
          conf.has_key?(k)
          @map[k] = v
        end
      }
    end

    def emit(tag, es, chain)
      es.each { |time, record|
        Engine.emit(@tag, time, modify_record(record))
      }

      chain.next
    end

    private

    def modify_record(record)
      @map.each_pair { |k, v|
        record[k] = v
      }

      record
    end
  end
end
