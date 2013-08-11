require 'fluentd/plugin/filter'

module Fluentd
  module Plugin
    class RecordModifierFilter < Filter
      Plugin.register_filter('record_modifier', self)

      config_param :include_tag_key, :bool, :default => false
      config_param :tag_key, :string, :default => 'tag'
      config_param :include_time_key, :bool, :default => false
      config_param :time_key, :string, :default => 'time'
      config_param :time_as_epoch, :bool, :default => false

      BUILTIN_PARAMS = %W(type include_tag_key tag_key include_time_key time_key time_as_epoch time_format localtime utf)

      def configure(conf)
        super

        @adders = {}
        conf.each_pair { |k, v|
          unless BUILTIN_PARAMS.include?(k)
            conf.has_key?(k)
            @adders[k] = v
          end
        }

        if @include_time_key && !@time_as_epoch
          @timef = TimeFormatter.configure(conf)
        end
      end

      def emit(tag, time, record)
        collector.emit(tag, time, modify_record(tag, time, record))
      end

      def emits(tag, es)
        modified_es = MultiEventCollection.new
        es.each { |time, record|
          modified_es.add(time, modify_record(tag, time, record))
        }

        collector.emits(tag, modified_es)
      end

      private

      def modify_record(tag, time, record)
        if @include_tag_key
          record[@tag_key] = tag
        end
        if @include_time_key
          record[@time_key] = @time_as_epoch ? time : @timef.format(time)
        end

        @adders.each_pair { |k, v|
          record[k] = v
        }

        record
      end

      class TimeFormatter
        def initialize(format, localtime)
          @tc1 = 0
          @tc1_str = nil
          @tc2 = 0
          @tc2_str = nil

          if format
            if localtime
              define_singleton_method(:format_nocache) { |time|
                Time.at(time).strftime(format)
              }
            else
              define_singleton_method(:format_nocache) { |time|
                Time.at(time).utc.strftime(format)
              }
            end
          else
            if localtime
              define_singleton_method(:format_nocache) { |time|
                Time.at(time).iso8601
              }
            else
              define_singleton_method(:format_nocache) { |time|
                Time.at(time).utc.iso8601
              }
            end
          end
        end

        def format(time)
          if @tc1 == time
            return @tc1_str
          elsif @tc2 == time
            return @tc2_str
          else
            str = format_nocache(time)
            if @tc1 < @tc2
              @tc1 = time
              @tc1_str = str
            else
              @tc2 = time
              @tc2_str = str
            end
            return str
          end
        end

        def format_nocache(time)
          # will be overridden in initialize
        end

        def self.configure(conf)
          if localtime = conf['localtime']
            localtime = true
          elsif utc = conf['utc']
            localtime = false
          end

          new(conf['time_format'], localtime)
        end
      end
    end
  end
end
